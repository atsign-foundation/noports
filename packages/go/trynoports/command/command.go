package command

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

const WelcomeMessageContent = `Welcome to the NoPorts Trial environment!

This environment allows you to test out NoPorts before doing device setup. If you're seeing this message, your client was set up correctly!

We have a few cool tricks you can try while you are here:

#1 - List out all the network interfaces
#2 - Run nmap to scan the public interface for open ports

Combined, these will show you that there aren't any inbound ports open on this machine. We've taken a number of precautions to ensure that we minimize the network attack surface when you use NoPorts, while also making it as easy to use as possible. If you're curious about how the technology works, or you want to learn more about how we handle security, please visit our site:

https://www.noports.com/sshnp-how-it-works

Hint: To see the full controls of this application, press "?"
`

type (
	CommandResult  struct{ err error }
	RunnerWithDone interface {
		Run(done chan int) (chan string, error)
	}
	// Type to define the commands available above
	AppCommand struct {
		Label string
		Cmd   string
		Args  []string
	}
	WelcomeMessage struct{}
)

func (c AppCommand) FilterValue() string { return c.Label }
func (c AppCommand) Title() string       { return c.Label }
func (c AppCommand) Description() string {
	return fmt.Sprintf("%s %s", c.Cmd, strings.Join(c.Args, " "))
}

func (c AppCommand) Run(done chan int) (chan string, error) {
	ch := make(chan string, 100) // channel for the output to the terminal - for now this program will not take input, too much risk without further thinking
	cmd := exec.Command(c.Cmd, c.Args...)
	pipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	cmd.Stderr = cmd.Stdout

	err = cmd.Start()
	if err != nil {
		return nil, err
	}

	cmdDone := make(chan error, 1)
	go func() {
		err := cmd.Wait()
		time.Sleep(250 * time.Millisecond) // Give the pipe enough time to clear - also prevents clients from running > 4 commands / second
		cmdDone <- err
	}()

	go func() {
		var buf [256]byte
		for {
			select {
			case <-cmdDone:
				pipe.Close()
				close(cmdDone)
				done <- 0
				return
			default:
				n, err := pipe.Read(buf[:])
				if n > 0 {
					ch <- string(buf[:n])
				}
				if err != nil {
					continue
				}
			}
		}
	}()

	return ch, nil
}

func (c WelcomeMessage) FilterValue() string { return "Show the Welcome Message" }
func (c WelcomeMessage) Title() string       { return "Show the Welcome Message" }
func (c WelcomeMessage) Description() string { return "(The text shown when you first connected)" }
func (c WelcomeMessage) Run(done chan int) (chan string, error) {
	ch := make(chan string, 100)

	go func() {
		ch <- WelcomeMessageContent
		time.Sleep(250 * time.Millisecond) // Give the pipe enough time to clear - also prevents clients from running > 4 commands / second
		done <- 0
	}()

	return ch, nil
}
