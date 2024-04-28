package main

// Update part of Elm architecture for app

import (
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func (m appState) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var (
		cmd  tea.Cmd
		cmds []tea.Cmd
	)

	// Cache this at the start of the update, since it may change mid way through

	// Handle terminal / input events first
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m, cmd = m.WindowSizeMsg(msg)
		cmds = append(cmds, cmd)
	case tea.KeyMsg:
		m, cmd = m.KeyMsg(msg)
		cmds = append(cmds, cmd)
	}

	// Update the view contents
	if m.viewport.isReady {
		// Update viewport
		m.viewport.model, cmd = m.viewport.model.Update(msg)
		cmds = append(cmds, cmd)
	}
	// Update the list
	m.list.model, cmd = m.list.model.Update(msg)
	cmds = append(cmds, cmd)

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
	case "enter":
		if useHighPerformanceRenderer {
			viewport.Sync(m.viewport.model)
		}
		// TODO:
		// - Somehow stream it to content
	}

	return m, nil
}

// Update the window size when it is reported to us
func (m appState) WindowSizeMsg(msg tea.WindowSizeMsg) (appState, tea.Cmd) {
	frameW, frameH := m.frame.style.GetFrameSize()
	listFrameW := m.list.style.GetHorizontalFrameSize()
	listWidth := lipgloss.Width(m.list.model.View())
	viewportFrameW, viewportFrameH := m.viewport.style.GetFrameSize()

	w := msg.Width - frameW - listFrameW - listWidth - viewportFrameW
	h := msg.Height - frameH - viewportFrameH

	m.list.model.SetSize(w, h)
	if !m.viewport.isReady {
		m.viewport.model = viewport.New(w, h)
		m.viewport.model.SetContent("> ")
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
