package command

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

type ExecCmd struct {
	Label string
	Cmd   string
	Args  []string
}

func (c ExecCmd) FilterValue() string { return c.Label }
func (c ExecCmd) Title() string       { return c.Label }
func (c ExecCmd) Description() string {
	return fmt.Sprintf("%s %s", c.Cmd, strings.Join(c.Args, " "))
}

func (c ExecCmd) Run(done chan int) (chan string, error) {
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
