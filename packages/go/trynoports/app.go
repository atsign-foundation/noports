package main

// Model / Init part of Elm architecture for app

import (
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/bubbletea"
	"github.com/muesli/termenv"
)

// Main application state, composed of 3 sub-models
type appState struct {
	program  *tea.Program
	frame    appFrame
	list     appList
	viewport appViewport
	focused  int // 0 = list, 1 = viewport
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
	style     lipgloss.Style
	model     viewport.Model
	content   string
	spinner   spinner.Model
	isRunning bool
	isReady   bool
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

func AppMiddleware() wish.Middleware {
	newProg := func(m appState, opts ...tea.ProgramOption) *tea.Program {
		p := tea.NewProgram(m, opts...)
		go func() {
			// register a pointer to the program with itself, so we can send async messages back to the viewport later
			p.Send(ProgramMsg{p})
		}()
		return p
	}
	teaHandler := func(s ssh.Session) *tea.Program {
		pty, _, _ := s.Pty()
		renderer := bubbletea.MakeRenderer(s)
		frameStyle := renderer.NewStyle().Margin(2)
		appHeight := pty.Window.Height - frameStyle.GetVerticalFrameSize()
		listStyle := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("7")).Height(appHeight)
		viewportStyle := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("244")).MarginLeft(2).Padding(1).Height(appHeight)

		// Spinner
		spin := spinner.New()
		spin.Spinner = spinner.Dot

		// List styles application

		// Main state initialization
		m := appState{
			frame: appFrame{
				width:  pty.Window.Width,
				height: pty.Window.Height,
				style:  frameStyle,
			},
			list: appList{
				style: listStyle,
				model: InitCommands(list.NewDefaultDelegate(), 0, appHeight-listStyle.GetVerticalFrameSize()),
			},
			viewport: appViewport{
				style:   viewportStyle,
				spinner: spin,
			},
			focused: 0, // focus list by default
		}
		m.list.model.Title = title
		m.list.model.AdditionalShortHelpKeys = func() []key.Binding {
			return []key.Binding{
				key.NewBinding(
					key.WithKeys("enter"),
					key.WithHelp("enter", "Run the currently selected command"),
				),
			}
		}
		m.list.model.AdditionalFullHelpKeys = func() []key.Binding {
			return []key.Binding{
				key.NewBinding(
					key.WithKeys(tea.KeyCtrlD.String()),
					key.WithHelp("Ctrl+D", "Scroll down in the viewport"),
				),
				key.NewBinding(
					key.WithKeys(tea.KeyCtrlU.String()),
					key.WithHelp("Ctrl+U", "Scroll up in the viewport"),
				),
				key.NewBinding(
					key.WithKeys("enter"),
					key.WithHelp("enter", "Run the currently selected command"),
				),
			}
		}

		return newProg(m, append(bubbletea.MakeOptions(s), tea.WithAltScreen())...)
	}
	return bubbletea.MiddlewareWithProgramHandler(teaHandler, termenv.ANSI256)
}
