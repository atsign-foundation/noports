package app

import (
	tea "github.com/charmbracelet/bubbletea"
)

type InstallServiceForm2Model struct {
	form Form
}

func InitialManageServiceForm2Model() InstallServiceForm2Model {
	model := InstallServiceForm2Model{}
	return model
}

func (m InstallServiceForm2Model) Update(msg tea.Msg) (InstallServiceForm2Model, tea.Cmd) {
	var cmd tea.Cmd
	m.form, cmd = m.form.Update(msg)
	return m, cmd
}

func (m InstallServiceForm2Model) View() string {
	return m.form.View()
}
