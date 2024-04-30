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
		m = m.KeyMsg(msg)
	}

	// Update the view contents
	if m.viewport.isReady {
		// Update viewport
		m.viewport.model, cmd = m.viewport.model.Update(msg)
		cmds = append(cmds, cmd)
	} else {
		m.viewport.spinner, cmd = m.viewport.spinner.Update(msg)
		cmds = append(cmds, cmd)
	}

	// Update the list
	m.list.model, cmd = m.list.model.Update(msg)
	cmds = append(cmds, cmd)

	// Batch all of the potential commands
	return m, tea.Batch(cmds...)
}

// Handle keyboard input
func (p appState) KeyMsg(msg tea.KeyMsg) (m appState) {
	m = p
	switch msg.String() {
	case "enter":
		if m.viewport.isRunning {
			return
		} else {
			m.viewport.isRunning = true
		}
		// Update the command entry
		command := m.list.model.SelectedItem().(appCommand).command
		args := strings.Join(m.list.model.SelectedItem().(appCommand).args, " ")
		// Throw away the old contents, otherwise someone malicious might try to allocate infinite memory to that struct
		m.viewport.content = fmt.Sprintf("> %s %s\n", command, args)
		m.viewport.model.SetContent(m.viewport.content)
		m.viewport.model.GotoBottom()

		if useHighPerformanceRenderer {
			viewport.Sync(m.viewport.model)
		}

		done := make(chan int, 1)
		ch, err := m.list.model.SelectedItem().(appCommand).Run(done)
		if err != nil {
			close(done)
			m.viewport.content = fmt.Sprintf("> %s %s\nOops! We messed up, can't run this command right now...", command, args)
			m.viewport.model.SetContent(m.viewport.content)
			m.viewport.model.GotoBottom()
			m.viewport.isRunning = false
			fmt.Printf("Error running command: %s\n", err)
			return
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

	return
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
		m.viewport.model.SetContent("> ") // TODO  add welcome message
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
