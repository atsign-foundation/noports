package main

import (
	"context"
	"errors"
	"flag"
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
	title                      = "Welcome to Atsign's NoPorts Trial Environment!"
	host                       = "localhost"
	port                       = "23234"
	keyPath                    = ".ssh/id_ed25519"
	useHighPerformanceRenderer = false
	welcomeMessageContent      = `Welcome to the NoPorts Trial environment!

This environment allows you to test out NoPorts before doing device setup. If you're seeing this message, your client was set up correctly!

We have a few cool tricks you can try while you are here:

#1 - List out all the network interfaces
#2 - Run nmap to scan the public interface for open ports

Combined, these will show you that there aren't any inbound ports open on this machine. We've taken a number of precautions to ensure that we minimize the network attack surface when you use NoPorts, while also making it as easy to use as possible. If you're curious about how the technology works, or you want to learn more about how we handle security, please visit our site:

https://www.noports.com/sshnp-how-it-works

Hint: To see the full controls of this application, press "?"
`
)

// Program inputs
var (
	Flagh = flag.String("h", "", "set the host for the nmap command")
	Flagf = flag.Bool("f", false, "use the ifconfig instead of ip addr")
)

// Setup the server (main server lifecycle)
func main() {
	flag.Parse()
	log.Info("Environment", "nmap host (-h)", *Flagh, "use ifconfig (-f)", *Flagf)

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
