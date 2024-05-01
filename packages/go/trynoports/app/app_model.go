package app

// Model / Init part of Elm architecture for app

import (
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Main application state, composed of 3 sub-models
type appState struct {
	program  *tea.Program
	list     appList
	frame    appFrame
	viewport appViewport
	width    int
	height   int
	focused  int
}

type appFrame struct {
	style  lipgloss.Style
	width  int
	height int
}

type appList struct {
	model list.Model
	style lipgloss.Style
}

type appViewport struct {
	style        lipgloss.Style
	content      string
	model        viewport.Model
	spinner      spinner.Model
	contentIndex int
	isRunning    bool
	isReady      bool
}

func (m appState) Init() tea.Cmd {
	return m.viewport.spinner.Tick
}

type ProgramMsg struct {
	program *tea.Program
}
type ViewportContentMsg struct {
	content string
}

type CmdDoneMsg struct{}
