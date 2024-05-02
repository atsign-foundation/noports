package app

// Model / Init part of Elm architecture for app

import (
	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Main application state, composed of 3 sub-models
type (
	appState struct {
		program  *tea.Program
		list     appList
		help     appHelp
		frame    lipgloss.Style
		viewport appViewport
		width    int
		height   int
		focused  int
	}
	appList struct {
		model list.Model
		style lipgloss.Style
	}
	appViewport struct {
		style        lipgloss.Style
		content      string
		model        viewport.Model
		spinner      spinner.Model
		contentIndex int
		isRunning    bool
		isReady      bool
	}
	appHelp struct {
		keys  AppKeyMap
		model help.Model
	}
)

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
