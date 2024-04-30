package main

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/list"
)

// Available system commands
func InitCommands(d list.ItemDelegate, width int, height int) list.Model {
	return list.New(
		[]list.Item{
			welcomeMessage{},
			func() appCommand {
				if *Flagf {
					return appCommand{
						title:   "Show Network Interface",
						command: "ifconfig",
						args:    []string{},
					}
				} else {
					return appCommand{
						title:   "Show Network Interface",
						command: "ip",
						args:    []string{"addr"},
					}
				}
			}(),
			appCommand{
				title:   "Scan All Ports",
				command: "nmap",
				args:    []string{"-p", "1-65535", *Flagh},
			},
		},
		d, 0, 0,
	)
}

type (
	CommandResult  struct{ err error }
	RunnerWithDone interface {
		Run(done chan int) (chan string, error)
	}
	// Type to define the commands available above
	appCommand struct {
		title   string
		command string
		args    []string
	}
	welcomeMessage struct{}
)

func (c appCommand) FilterValue() string { return c.title }
func (c appCommand) Title() string       { return c.title }
func (c appCommand) Description() string {
	return fmt.Sprintf("%s %s", c.command, strings.Join(c.args, " "))
}

func (c appCommand) Run(done chan int) (chan string, error) {
	ch := make(chan string, 100) // channel for the output to the terminal - for now this program will not take input, too much risk without further thinking
	cmd := exec.Command(c.command, c.args...)
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

func (c welcomeMessage) FilterValue() string { return "Show the Welcome Message" }
func (c welcomeMessage) Title() string       { return "Show the Welcome Message" }
func (c welcomeMessage) Description() string { return "(The text shown when you first connected)" }
func (c welcomeMessage) Run(done chan int) (chan string, error) {
	ch := make(chan string, 100)

	go func() {
		ch <- welcomeMessageContent
		time.Sleep(250 * time.Millisecond) // Give the pipe enough time to clear - also prevents clients from running > 4 commands / second
		done <- 0
	}()

	return ch, nil
}
