package app

import (
	tea "github.com/charmbracelet/bubbletea"
)

type InstallServiceForm3Model struct{}

func InitialManageServiceForm3Model() InstallServiceForm3Model {
	model := InstallServiceForm3Model{}
	return model
}

func (m InstallServiceForm3Model) Update(msg tea.Msg) (InstallServiceForm3Model, tea.Cmd) {
	return m, nil
}

func (m InstallServiceForm3Model) View() string {
	return "Manage Service Form 3"
}
