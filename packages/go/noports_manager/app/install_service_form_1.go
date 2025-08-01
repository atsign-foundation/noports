package app

import (
	tea "github.com/charmbracelet/bubbletea"
)

type InstallServiceForm1Model struct {
	form Form
}

func InitialManageServiceForm1Model() InstallServiceForm1Model {
	inputs := []FormInput{
		{
			TextInput: TextInput{
				Placeholder: "@blue123_device",
				Validate:    FormValidators.Atsign,
			},
			Label: "Device atSign",
		},
		{
			TextInput: TextInput{
				Placeholder: "my_device_123",
				Validate:    FormValidators.DeviceName,
			},
			Label: "Device name",
		},
	}

	model := InstallServiceForm1Model{
		form: CreateForm(inputs, NextPageCmd, PrevPageCmd),
	}
	return model
}

func (m InstallServiceForm1Model) Init() tea.Cmd {
	return m.form.Init()
}

func (m InstallServiceForm1Model) Update(msg tea.Msg) (InstallServiceForm1Model, tea.Cmd) {
	var cmd tea.Cmd
	m.form, cmd = m.form.Update(msg)
	return m, cmd
}

func (m InstallServiceForm1Model) View() string {
	return m.form.View()
}
