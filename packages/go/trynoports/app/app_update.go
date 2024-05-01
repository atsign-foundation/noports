package app

// Update part of Elm architecture for app

import (
	"command"
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/log"
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
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height

		// We have an initial window size now
		// Now it is safe to initialize the viewport
		if !m.viewport.isReady {
			// We will resize this to the correct size during the ResizeComponents call
			m.viewport.model = viewport.New(1, 1)
			m.viewport.content = command.WelcomeMessageContent
			m.viewport.model.HighPerformanceRendering = useHighPerformanceRenderer
			m.viewport.model.KeyMap.Down.SetEnabled(false)
			m.viewport.model.KeyMap.Up.SetEnabled(false)
			m.viewport.isReady = true
			if useHighPerformanceRenderer {
				cmds = append(cmds, viewport.Sync(m.viewport.model))
			}
		}

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

	// Recompute the size of the components based on current changes
	m, cmd = m.ResizeComponents(msg)
	cmds = append(cmds, cmd)

	// Batch all of the potential commands
	return m, tea.Batch(cmds...)
}

// Handle keyboard input
func (p appState) KeyMsg(msg tea.KeyMsg) (m appState) {
	m = p
	switch msg.String() {
	case "enter":
		if m.viewport.isRunning || m.list.model.Index() == m.viewport.contentIndex {
			return
		}
		m.viewport.isRunning = true
		m.viewport.contentIndex = m.list.model.Index()

		item := m.list.model.SelectedItem()
		var cmd, args string

		switch item.(type) {
		case command.AppCommand:
			// Update the command entry
			cmd = item.(command.AppCommand).Cmd
			args = strings.Join(m.list.model.SelectedItem().(command.AppCommand).Args, " ")
			// Throw away the old contents, otherwise someone malicious might try to allocate infinite memory to that struct
			m.viewport.content = fmt.Sprintf("> %s %s\n", cmd, args)

		default:
			m.viewport.content = ""
		}

		done := make(chan int, 1)
		ch, err := m.list.model.SelectedItem().(command.RunnerWithDone).Run(done)
		if err != nil {
			close(done)
			// Welcome command should never return an error, so it is safe to assume we have an appCommand in here
			// Thus command & args are set
			m.viewport.content = fmt.Sprintf("> %s %s\nOops! We messed up, can't run this command right now...", cmd, args)
			m.viewport.model.SetContent(m.viewport.content)
			m.viewport.model.GotoBottom()
			m.viewport.isRunning = false
			log.Error("Error running command: ", "error", err)
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
func (m appState) ResizeComponents(msg tea.Msg) (appState, tea.Cmd) {
	// get frame dimensions
	frameW, frameH := m.frame.style.GetFrameSize()

	// get preferred list dimensions
	m.list.model.SetSize(80, m.height-frameH)

	// do all the calculations to resize the viewport
	if m.viewport.isReady {
		// pseudo render the list to compute it's actual width
		// (can change during filtering or popping open the full help dialog)
		listW := lipgloss.Width(m.list.model.View())

		// get list & viewport frame sizes
		listFrameW, _ := m.list.style.GetFrameSize()
		viewportFrameW, viewportFrameH := m.viewport.style.GetFrameSize()

		// calculate viewport dimensions
		viewportW := m.width - frameW - viewportFrameW - listFrameW - listW
		viewportH := m.height - frameH - viewportFrameH

		// resize the viewport
		m.viewport.model.Width = viewportW
		m.viewport.model.Height = viewportH

		content := lipgloss.NewStyle().Width(viewportW).Render(m.viewport.content)
		m.viewport.model.SetContent(content)

		if useHighPerformanceRenderer {
			return m, viewport.Sync(m.viewport.model)
		}
	}

	return m, nil
}
