package main

// An example Bubble Tea server. This will put an ssh session into alt screen
// and continually print up to date terminal information.

import (
	"context"
	"errors"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/log"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/activeterm"
	"github.com/charmbracelet/wish/bubbletea"
	"github.com/charmbracelet/wish/logging"
)

// constants for the server
const (
	title                      = "Welcome to Try No Ports!"
	host                       = "localhost"
	port                       = "23234"
	keyPath                    = ".ssh/id_ed25519"
	useHighPerformanceRenderer = false
)

// Available system commands
var items = []list.Item{
	item{title: "List Ip Addresses", cmd: "ip addr"},
	item{title: "Scan All Ports", cmd: "nmap -p 1-65535 127.0.0.1"}, // TODO  replace 127 with actual ip
}

var actions = list.New(items, list.NewDefaultDelegate(), 0, 0)

// Items in the application
type item struct {
	title, cmd string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.cmd }
func (i item) FilterValue() string { return i.title }

// Command output viewport

// Main state of the TUI application
type model struct {
	list            list.Model
	docStyle        lipgloss.Style
	txtStyle        lipgloss.Style
	quitStyle       lipgloss.Style
	term            string
	viewportContent string
	viewport        viewport.Model
	width           int
	height          int
	viewportVisible bool
	viewportReady   bool
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var (
		cmd  tea.Cmd
		cmds []tea.Cmd
	)
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		x, y := m.docStyle.GetFrameSize()
		w := msg.Width - x
		h := msg.Height - y

		m.list.SetSize(w, h)
		if !m.viewportReady {
			m.viewport = viewport.New(w, h)
			m.viewport.HighPerformanceRendering = useHighPerformanceRenderer
			m.viewport.SetContent(m.viewportContent)
			m.viewportReady = true
		} else {
			m.viewport.Width = w
			m.viewport.Height = h
		}
		if useHighPerformanceRenderer {
			cmds = append(cmds, viewport.Sync(m.viewport))
		}
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "esc":
			if !m.viewportVisible {
				break
			}

			m.viewportVisible = false
			// TODO: cancel any running commands
		case "enter":
			if m.viewportVisible {
				break
			}

			m.viewportVisible = true
			m.viewport.SetContent("\n Yeah... I don't really know how to implement this yet, so here's a smiley\n :)\n")
			// TODO:
			// - Start command
			// - Somehow stream it to content
		}
	}

	if m.viewportReady && m.viewportVisible {
		m.viewport, cmd = m.viewport.Update(msg)
		cmds = append(cmds, cmd)
	} else {
		m.list, cmd = m.list.Update(msg)
	}

	cmds = append(cmds, cmd)
	return m, tea.Batch(cmds...)
}

func (m model) View() string {
	if m.viewportVisible {
		if !m.viewportReady {
			return "\n Initializing a new shell session..."
		}
		// TODO: put a nice frame around this with some help & the command being run as the title or something
		return m.docStyle.Render(m.viewport.View())
	}
	return m.docStyle.Render(m.list.View())
}

// Main connection handler, in this case we are using bubbletea to serve an app
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
	// This should never fail, as we are using the activeterm middleware.
	pty, _, _ := s.Pty()

	// provide some default stylings for the application
	renderer := bubbletea.MakeRenderer(s)
	docStyle := renderer.NewStyle().Margin(1, 2)

	m := model{
		term:     pty.Term,
		width:    pty.Window.Width,
		height:   pty.Window.Height,
		docStyle: docStyle,
		list:     actions,
	}
	m.list.Title = title

	// TODO: add enter to help keybinds

	return m, []tea.ProgramOption{tea.WithAltScreen()}
}

// Setup the server (main server lifecycle)
func main() {
	// Create the server object with appropriate middleware
	s, err := wish.NewServer(
		wish.WithAddress(net.JoinHostPort(host, port)),
		wish.WithHostKeyPath(keyPath),
		wish.WithMiddleware(
			bubbletea.Middleware(teaHandler),
			activeterm.Middleware(), // Bubble Tea apps usually require a PTY.
			logging.Middleware(),
		),
	)
	if err != nil {
		log.Error("Could not start server", "error", err)
	}

	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)
	log.Info("Starting SSH server", "host", host, "port", port)
	go func() {
		if err = s.ListenAndServe(); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
			log.Error("Could not start server", "error", err)
			done <- nil
		}
	}()

	<-done
	log.Info("Stopping SSH server")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer func() { cancel() }()
	if err := s.Shutdown(ctx); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
		log.Error("Could not stop server", "error", err)
	}
}
