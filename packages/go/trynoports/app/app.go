package app

import (
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/bubbletea"
	"github.com/muesli/termenv"
)

const (
	title                      = "Welcome to Atsign's NoPorts Trial Environment!"
	useHighPerformanceRenderer = false
)

func AppMiddleware(initCommands func(d list.ItemDelegate, width int, height int) list.Model) wish.Middleware {
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
				model: initCommands(list.NewDefaultDelegate(), 0, appHeight-listStyle.GetVerticalFrameSize()),
			},
			viewport: appViewport{
				style:   viewportStyle,
				spinner: spin,
			},
		}
		m.list.model.Title = title
		m.list.model.AdditionalShortHelpKeys = func() []key.Binding {
			return []key.Binding{
				key.NewBinding(
					key.WithKeys("enter"),
					key.WithHelp("enter", "run command"),
				),
			}
		}
		m.list.model.AdditionalFullHelpKeys = func() []key.Binding {
			return []key.Binding{
				key.NewBinding(
					key.WithKeys(tea.KeyCtrlD.String()),
					key.WithHelp("ctrl+d", "down (viewport)"),
				),
				key.NewBinding(
					key.WithKeys(tea.KeyCtrlU.String()),
					key.WithHelp("ctrl+u", "up (viewport)"),
				),
				key.NewBinding(
					key.WithKeys("enter"),
					key.WithHelp("enter", "run command"),
				),
			}
		}

		return newProg(m, append(bubbletea.MakeOptions(s), tea.WithAltScreen())...)
	}
	return bubbletea.MiddlewareWithProgramHandler(teaHandler, termenv.ANSI256)
}
