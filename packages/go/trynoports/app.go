package main

// Model / Init part of Elm architecture for app

import (
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish/bubbletea"
)

// Main application state, composed of 3 sub-models
type appState struct {
	frame    appFrame
	list     appList
	viewport appViewport
}

type appFrame struct {
	style  lipgloss.Style
	width  int
	height int
}

type appList struct {
	model list.Model
}

type appViewport struct {
	model     viewport.Model
	spinner   spinner.Model
	isVisible bool
	isReady   bool
}

func (m appState) Init() tea.Cmd {
	return m.viewport.spinner.Tick
}

// The actual bubbletea program (as middleware for a wish ssh session)
func App(s ssh.Session) (tea.Model, []tea.ProgramOption) {
	pty, _, _ := s.Pty()
	renderer := bubbletea.MakeRenderer(s)
	frameStyle := renderer.NewStyle().Margin(1, 2)
	spin := spinner.New()
	spin.Spinner = spinner.Dot

	m := appState{
		frame: appFrame{
			width:  pty.Window.Width,
			height: pty.Window.Height,
			style:  frameStyle,
		},
		list: appList{
			model: InitCommands(),
		},
		viewport: appViewport{
			spinner: spin,
		},
	}
	m.list.model.Title = title

	// TODO: add enter to help keybinds

	return m, []tea.ProgramOption{tea.WithAltScreen()}
}
