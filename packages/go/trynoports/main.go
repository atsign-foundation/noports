package main

import (
	"app"
	"command"
	"context"
	"errors"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"sshnpd"
	"strings"
	"syscall"
	"time"

	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/log"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/activeterm"
	"github.com/charmbracelet/wish/logging"
)

const (
	host = "localhost"
	port = 23234
)

// Available system commands
func InitCommands(d list.ItemDelegate, width int, height int) list.Model {
	return list.New(
		[]list.Item{
			command.WelcomeCmd{},
			func() command.ExecCmd {
				if *Flagf {
					return command.ExecCmd{
						Label: "Show Network Interface",
						Cmd:   "ifconfig",
						Args:  []string{},
					}
				} else {
					return command.ExecCmd{
						Label: "Show Network Interface",
						Cmd:   "ip",
						Args:  []string{"addr"},
					}
				}
			}(),
			command.ExecCmd{
				Label: "Scan All Ports",
				Cmd:   "nmap",
				Args:  []string{"-p", "1-65535", *Flagh},
			},
		},
		d, 0, 0,
	)
}

// Program inputs
var (
	Flagk = flag.String("k", ".ssh/id_ed25519", "host key path")
	Flagh = flag.String("h", "localhost", "set the host for the nmap command")
	Flagf = flag.Bool("f", false, "use the ifconfig instead of ip addr")
	// sshnpd flags
	FlagK    = flag.String("K", "", "-k for sshnpd")
	FlagA    = flag.String("A", "", "-a for sshnpd")
	FlagM    = flag.String("M", "", "-m for sshnpd")
	FlagD    = flag.String("D", "", "-d for sshnpd")
	FlagS    = flag.Bool("S", true, "-s for sshnpd")
	FlagU    = flag.Bool("U", true, "-u for sshnpd")
	FlagV    = flag.Bool("V", true, "-v for sshnpd")
	FlagArgs = flag.String("ARGS", "", "additional args for sshnpd (';' separated)")
)

// Setup the server (main server lifecycle)
func main() {
	flag.Parse()
	log.Info(
		"Environment",
		"host key path (-k)", *Flagk,
		"nmap host (-h)", *Flagh,
		"use ifconfig (-f)", *Flagf,
	)
	log.Info(
		"Sshnpd Args",
		"-k", *FlagK,
		"-a", *FlagA,
		"-m", *FlagM,
		"-d", *FlagD,
		"-s", *FlagS,
		"-u", *FlagU,
		"-v", *FlagV,
		"additional args", *FlagArgs,
	)

	if *Flagh == "localhost" {
		log.Warn("Detected the default nmap host, did you set the nmap host with `-h`?")
	}

	args := strings.Split(*FlagArgs, ";")

	if *FlagS {
		args = append(args, "-s")
	}

	if *FlagU {
		args = append(args, "-u")
	}

	if *FlagV {
		args = append(args, "-v")
	}

	sshnpdArgs := sshnpd.Args{
		KeyFile:    *FlagK,
		Atsign:     *FlagA,
		Managers:   *FlagM,
		DeviceName: *FlagD,
		Host:       host,
		Port:       port,
		Args:       args,
	}
	sshnpdCh := sshnpd.Start(sshnpdArgs)

	go func() {
		for msg := range sshnpdCh {
			switch signal := msg.(type) {
			case sshnpd.ErrorSignal:
				log.Error("Sshnpd failed to start", "signal.Err", signal.Err)
			case sshnpd.LogSignal:
				log.Info("Sshnpd | ", "Msg", string(signal.Msg[:]))
			case sshnpd.DoneSignal:
				log.Warn("Sshnpd Exited")
			}
		}
	}()

	// Create the server object with appropriate middleware
	s, err := wish.NewServer(
		wish.WithAddress(net.JoinHostPort(host, fmt.Sprintf("%d", port))),
		wish.WithHostKeyPath(*Flagk),
		wish.WithMiddleware(
			app.AppMiddleware(InitCommands),
			activeterm.Middleware(), // Bubble Tea apps usually require a PTY.
			logging.Middleware(),
		),
	)
	if err != nil {
		log.Error("Could not start server", "error", err)
	}

	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)
	log.Info("Starting SSH server", "host", host, "port", port)
	go func() {
		if err = s.ListenAndServe(); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
			log.Error("Could not start server", "error", err)
			done <- nil
		}
	}()

	<-done
	log.Info("Stopping SSH server")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer func() { cancel() }()
	if err := s.Shutdown(ctx); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
		log.Error("Could not stop server", "error", err)
	}
}
