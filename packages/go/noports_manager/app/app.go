package app

import (
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
)

const (
	mainMenuInitial      MenuIdx = 0
	mainMenuManageAtsign MenuIdx = 1
	mainMenuManageDevice MenuIdx = 2
)

// Initial State
func App() *tea.Program {
	items := []list.Item{
		MenuItem{label: "Manage atSigns", menuIdx: mainMenuManageAtsign},
		MenuItem{label: "Manage device install", menuIdx: mainMenuManageDevice},
	}
	initialState := model{
		menuIdx:           mainMenuInitial,
		menu:              CreateMenu(items, 40),
		ManageAtsignState: InitialManageAtsignModel(),
		ManageDeviceState: InitialManageDeviceModel(),
	}

	return tea.NewProgram(initialState)
}

// Main State
type model struct {
	ManageAtsignState ManageAtsignModel
	menu              list.Model
	ManageDeviceState ManageDeviceModel
	menuIdx           MenuIdx
}

// Main controller

func (m model) Init() tea.Cmd {
	return m.ManageDeviceState.Init()
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit
		}
	}
	switch m.menuIdx {
	case mainMenuManageAtsign:
		var cmd tea.Cmd
		m.ManageAtsignState, cmd = m.ManageAtsignState.Update(msg)
		return m, cmd
	case mainMenuManageDevice:
		var cmd tea.Cmd
		m.ManageDeviceState, cmd = m.ManageDeviceState.Update(msg)
		return m, cmd
	case mainMenuInitial:
		break
	default:
		m.menuIdx = mainMenuInitial
	}
	// Handle menuInitial here
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.menu.SetWidth(msg.Width)
		return m, nil
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "enter":
			i, ok := m.menu.SelectedItem().(MenuItem)
			if ok {
				m.menuIdx = i.menuIdx
			}
			return m, nil
		}
	}
	// Update the list
	var cmd tea.Cmd
	m.menu, cmd = m.menu.Update(msg)
	return m, cmd
}

func (m model) View() string {
	switch m.menuIdx {
	case mainMenuManageAtsign:
		return m.ManageAtsignState.View()
	case mainMenuManageDevice:
		return m.ManageDeviceState.View()
	default:
		return "\n" + m.menu.View()
	}
}
