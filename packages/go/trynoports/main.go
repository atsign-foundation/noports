package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/charmbracelet/log"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/activeterm"
	"github.com/charmbracelet/wish/logging"
)

const (
	title                      = "Welcome to Atsign's No Ports!"
	host                       = "localhost"
	port                       = "23234"
	keyPath                    = ".ssh/id_ed25519"
	useHighPerformanceRenderer = false
	welcomeMessageContent      = "Hello!\n"
)

// Program inputs
var (
	Flagh = flag.String("h", "", "set the host for the nmap command")
	Flagf = flag.Bool("f", false, "use the ifconfig instead of ip addr")
)

// Setup the server (main server lifecycle)
func main() {
	flag.Parse()
	fmt.Println("Environment")
	fmt.Printf(" - h: %s\n", *Flagh)
	fmt.Printf(" - f: %t\n", *Flagf)

	// Create the server object with appropriate middleware
	s, err := wish.NewServer(
		wish.WithAddress(net.JoinHostPort(host, port)),
		wish.WithHostKeyPath(keyPath),
		wish.WithMiddleware(
			AppMiddleware(),
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
