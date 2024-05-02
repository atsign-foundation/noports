package app

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
)

// View part of Elm architecture for app

func (m appState) View() string {
	help := m.RenderHelp()
	return m.frame.Render(
		lipgloss.JoinVertical(
			lipgloss.Center,
			lipgloss.JoinHorizontal(
				lipgloss.Top,
				m.RenderList(m.list.style),
				m.RenderViewport(m.viewport.style),
			),
			help,
		),
	)
}

func (m appState) RenderViewport(style lipgloss.Style) string {
	return style.Render(
		func() string {
			if !m.viewport.isReady {
				return fmt.Sprintf("%s Initializing a new shell session...", m.viewport.spinner.View())
			}
			return m.viewport.model.View()
		}(),
	)
}

func (m appState) RenderList(style lipgloss.Style) string {
	return style.Render(m.list.model.View())
}

func (m appState) RenderHelp() string {
	if fullHelpOnly {
		return m.help.model.FullHelpView(m.help.keys.FullHelpOnly())
	}

	// pad the help so it takes up its maximum space
	gap := ""
	if !m.help.model.ShowAll {
		for range FullHelpHeight - 1 {
			gap += "\n"
		}
	}
	return gap + m.help.model.View(m.help.keys)
}
