package main

// Update part of Elm architecture for app

import (
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
)

func (m appState) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var (
		cmd  tea.Cmd
		cmds []tea.Cmd
	)

	// Cache this at the start of the update, since it may change mid way through
	inViewport := m.viewport.isVisible

	// Handle terminal / input events first
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m, cmd = m.WindowSizeMsg(msg)
		cmds = append(cmds, cmd)
	case tea.KeyMsg:
		m, cmd = m.KeyMsg(msg)
		cmds = append(cmds, cmd)
		if inViewport { // Don't handle key events for viewport outside of our own logic
			return m, tea.Batch(cmds...)
		}
	}

	// Update the view contents
	if m.viewport.isVisible {
		if m.viewport.isReady {
			// Update viewport
			m.viewport.model, cmd = m.viewport.model.Update(msg)
			cmds = append(cmds, cmd)
		}
	} else {
		// Update the list
		m.list.model, cmd = m.list.model.Update(msg)
		cmds = append(cmds, cmd)
	}

	// Keep spinning
	if !m.viewport.isReady {
		m.viewport.spinner, cmd = m.viewport.spinner.Update(msg)
		cmds = append(cmds, cmd)
	}
	// Batch all of the potential commands
	return m, tea.Batch(cmds...)
}

// Handle keyboard input
func (m appState) KeyMsg(msg tea.KeyMsg) (appState, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		return m, tea.Quit // ctrl+c always quits
	case "q", tea.KeyEsc.String(): // escape and q do the same thing
		m.viewport.isVisible = false // leave the viewport if we are in it
		// TODO: cancel running commands

	case "enter":
		if m.viewport.isVisible {
			return m, nil // Disable enter in the viewport
		}

		m.viewport.isVisible = true
		m.viewport.model.SetContent("\n Yeah... I don't really know how to implement this yet, so here's a smiley\n :)\n")
		// TODO:
		// - Start command
		// - Somehow stream it to content
	}

	return m, nil
}

// Update the window size when it is reported to us
func (m appState) WindowSizeMsg(msg tea.WindowSizeMsg) (appState, tea.Cmd) {
	x, y := m.frame.style.GetFrameSize()
	w := msg.Width - x
	h := msg.Height - y

	m.list.model.SetSize(w, h)
	if !m.viewport.isReady {
		m.viewport.model = viewport.New(w, h)
		m.viewport.model.HighPerformanceRendering = useHighPerformanceRenderer
		m.viewport.isReady = true
	} else {
		m.viewport.model.Width = w
		m.viewport.model.Height = h
	}

	if useHighPerformanceRenderer {
		return m, viewport.Sync(m.viewport.model)
	}
	return m, nil
}
