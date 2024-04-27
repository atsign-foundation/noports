package main

import "fmt"

// View part of Elm architecture for app

func (m appState) View() string {
	if m.viewport.isVisible {
		if !m.viewport.isReady {
			return fmt.Sprintf("%s Initializing a new shell session...", m.viewport.spinner.View())
		}
		// TODO: put a nice frame around this with some help & the command being run as the title or something
		return m.frame.style.Render(m.viewport.model.View())
	}

	// Show the list of commands
	return m.frame.style.Render(m.list.model.View())
}
