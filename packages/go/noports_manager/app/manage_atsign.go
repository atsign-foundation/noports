package app

import tea "github.com/charmbracelet/bubbletea"

type ManageAtsignModel struct{}

func InitialManageAtsignModel() ManageAtsignModel {
	return ManageAtsignModel{}
}

func (m ManageAtsignModel) Update(msg tea.Msg) (ManageAtsignModel, tea.Cmd) {
	return m, nil
}

func (m ManageAtsignModel) View() string {
	return "Manage Atsign Scrasdfeen"
}
