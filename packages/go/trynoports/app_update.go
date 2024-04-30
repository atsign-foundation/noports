package main

// Update part of Elm architecture for app

import (
	"fmt"
	"strings"

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
	case ProgramMsg:
		m.program = msg.program
	case CmdDoneMsg:
		m.viewport.isRunning = false
	case ViewportContentMsg:
		m.viewport.content += msg.content
		m.viewport.model.SetContent(m.viewport.content)
		m.viewport.model.GotoBottom()
		if useHighPerformanceRenderer {
			viewport.Sync(m.viewport.model)
		}
	case tea.WindowSizeMsg:
		m, cmd = m.WindowSizeMsg(msg)
		cmds = append(cmds, cmd)
	case tea.KeyMsg:
		m, cmd = m.KeyMsg(msg)
		cmds = append(cmds, cmd)
	}

	// Update the view contents
	switch msg.(type) {
	case tea.KeyMsg:
		break
	default:
		if m.viewport.isReady {
			// Update viewport
			m.viewport.model, cmd = m.viewport.model.Update(msg)
			cmds = append(cmds, cmd)
		}
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
		if m.viewport.isRunning {
			return m, nil
		} else {
			m.viewport.isRunning = true
		}
		// Update the command entry
		command := m.list.model.SelectedItem().(appCommand).command
		args := strings.Join(m.list.model.SelectedItem().(appCommand).args, " ")
		if len(m.viewport.content) == 0 {
			m.viewport.content = fmt.Sprintf("> %s %s\n", command, args)
		} else {
			m.viewport.content = fmt.Sprintf("%s\n> %s %s\n", m.viewport.content, command, args)
		}
		m.viewport.model.SetContent(m.viewport.content)
		m.viewport.model.GotoBottom()

		if useHighPerformanceRenderer {
			viewport.Sync(m.viewport.model)
		}

		done := make(chan int, 1)
		ch, err := m.list.model.SelectedItem().(appCommand).Run(done)
		if err != nil {
			fmt.Printf("got an error: %s\n", err)
			return m, nil
		}

		go func() {
			for {
				select {
				case <-done:
					close(ch)
					close(done)
					m.program.Send(CmdDoneMsg{})
					return
				case msg := <-ch:
					m.program.Send(ViewportContentMsg{msg})
				}
			}
		}()
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
