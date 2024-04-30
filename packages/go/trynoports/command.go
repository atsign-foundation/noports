package main

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/list"
)

// Available system commands
func InitCommands(d list.ItemDelegate, width int, height int) list.Model {
	return list.New(
		[]list.Item{
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

type CommandResult struct{ err error }

// Type to define the commands available above
type appCommand struct {
	title   string
	command string
	args    []string
}

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
		cmdDone <- cmd.Wait()
	}()
	go func() {
		var buf [256]byte
		for {
			select {
			case <-cmdDone:
				pipe.Close()
				close(cmdDone)
				done <- 0
				fmt.Println("Done reading command")
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

func waitForCommand(cmd exec.Cmd, ch chan error) {
	err := cmd.Wait()
	ch <- err
}

func mergeCommandBuffers(ch chan string, errCh chan string, errExitCh chan int, outCh chan string, outExitCh chan int, innerDoneCh chan error, done chan int) {
}
