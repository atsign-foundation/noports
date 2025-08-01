package app

import (
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
)

const (
	deviceMenuInitial MenuIdx = iota
	deviceMenuInstall
	deviceMenuUninstall
)

type ManageDeviceModel struct {
	menu         list.Model
	InstallState InstallServiceModel
	menuIdx      MenuIdx
}

func InitialManageDeviceModel() ManageDeviceModel {
	items := []list.Item{
		MenuItem{label: "Install", menuIdx: deviceMenuInstall},
		MenuItem{label: "Uninstall", menuIdx: deviceMenuUninstall},
	}
	return ManageDeviceModel{
		menuIdx:      deviceMenuInitial,
		menu:         CreateMenu(items, 40),
		InstallState: InitialInstallServiceModel(),
	}
}

func (m ManageDeviceModel) Init() tea.Cmd {
	return m.InstallState.Init()
}

func (m ManageDeviceModel) Update(msg tea.Msg) (ManageDeviceModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit
		}
	}
	switch m.menuIdx {
	case deviceMenuInstall:
		var cmd tea.Cmd
		m.InstallState, cmd = m.InstallState.Update(msg)
		return m, cmd
	case deviceMenuUninstall:
		// TODO
		return m, nil
	case deviceMenuInitial:
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

func (m ManageDeviceModel) View() string {
	switch m.menuIdx {
	case deviceMenuInstall:
		return m.InstallState.View()
	case deviceMenuUninstall:
		// TODO
		return "Not implemented"
	default:
		return "\n" + m.menu.View()
	}
}
