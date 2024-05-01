package main

import (
	"app"
	"command"
	"context"
	"errors"
	"flag"
	"net"
	"os"
	"os/signal"
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
	host    = "localhost"
	port    = "23234"
	keyPath = ".ssh/id_ed25519"
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
	Flagh = flag.String("h", "localhost", "set the host for the nmap command")
	Flagf = flag.Bool("f", false, "use the ifconfig instead of ip addr")
)

// Setup the server (main server lifecycle)
func main() {
	flag.Parse()
	log.Info("Environment", "nmap host (-h)", *Flagh, "use ifconfig (-f)", *Flagf)

	if *Flagh == "localhost" {
		log.Warn("Detected the default nmap host, did you set the nmap host with `-h`?")
	}

	// Create the server object with appropriate middleware
	s, err := wish.NewServer(
		wish.WithAddress(net.JoinHostPort(host, port)),
		wish.WithHostKeyPath(keyPath),
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
