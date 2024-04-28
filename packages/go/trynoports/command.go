package main

import (
	"fmt"

	"github.com/charmbracelet/bubbles/list"
)

// Type to define the commands available above
type appCommand struct {
	title   string
	command string
}

func (c appCommand) FilterValue() string { return c.title }
func (c appCommand) Title() string       { return c.title }
func (c appCommand) Description() string { return c.command }

// Available system commands
func InitCommands(d list.ItemDelegate, width int, height int) list.Model {
	return list.New(
		[]list.Item{
			appCommand{
				title:   "Show Network Interface",
				command: "ip addr",
			},
			appCommand{
				title:   "Scan All Ports",
				command: fmt.Sprintf("nmap -p 1-65535 %s", *Ip),
			},
		},
		d, 0, 0,
	)
}

type CommandResult struct{ err error }
