package app

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
)

// View part of Elm architecture for app

func (m appState) View() string {
	return m.frame.style.Render(
		lipgloss.JoinHorizontal(
			lipgloss.Top,
			m.RenderList(m.list.style),
			m.RenderViewport(m.viewport.style),
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
