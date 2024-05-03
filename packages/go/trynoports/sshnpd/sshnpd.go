package sshnpd

import (
	"fmt"
	"os/exec"
	"time"
)

type (
	Signal     interface{}
	DoneSignal struct{}
	LogSignal  struct {
		Msg []byte
	}
	ErrorSignal struct {
		Err error
	}
)

type Args struct {
	KeyFile    string
	Atsign     string
	DeviceName string
	Host       string
	Managers   string
	Args       []string
	Port       int
}

func Start(args Args) chan Signal {
	ch := make(chan Signal)
	go _Start(args, ch)
	return ch
}

func _Start(args Args, ch chan Signal) {
	if len(args.DeviceName) == 0 {
		args.DeviceName = "trynoports"
	}
	cmdArgs := append(
		[]string{
			"-a", args.Atsign,
			"-m", args.Managers,
			"-d", args.DeviceName,
			"--po", fmt.Sprintf("%s:%d", args.Host, args.Port),
		},
		args.Args...,
	)

	if len(args.KeyFile) > 0 {
		cmdArgs = append(cmdArgs, "-k", args.KeyFile)
	}

	cmd := exec.Command("sshnpd", cmdArgs...)
	pipe, err := cmd.StdoutPipe()
	if err != nil {
		ch <- ErrorSignal{err}
		return
	}
	cmd.Stderr = cmd.Stdout

	err = cmd.Start()
	if err != nil {
		ch <- ErrorSignal{err}
		return
	}

	cmdDone := make(chan error, 1)
	go func() {
		err := cmd.Wait()
		time.Sleep(time.Second) // Give the pipe enough time to clear - also prevents clients from running > 4 commands / second
		cmdDone <- err
	}()

	go func() {
		var buf [256]byte
		for {
			select {
			case <-cmdDone:
				pipe.Close()
				close(cmdDone)
				ch <- DoneSignal{}
				return
			default:
				n, err := pipe.Read(buf[:])
				if n > 0 {
					ch <- LogSignal{buf[:n]}
				}
				if err != nil {
					continue
				}
			}
		}
	}()
}
