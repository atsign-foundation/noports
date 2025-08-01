package app

import (
	tea "github.com/charmbracelet/bubbletea"
)

const (
	Page1 page = iota
	Page2
	Page3
	Page4
	Page5
)

type InstallServiceModel struct {
	Form2 InstallServiceForm2Model
	Form3 InstallServiceForm3Model
	Form1 InstallServiceForm1Model
	Page  page
}

func InitialInstallServiceModel() InstallServiceModel {
	model := InstallServiceModel{
		Page:  Page1,
		Form1: InitialManageServiceForm1Model(),
	}
	return model
}

func (m InstallServiceModel) Init() tea.Cmd {
	return m.Form1.Init()
}

func (m InstallServiceModel) Update(msg tea.Msg) (InstallServiceModel, tea.Cmd) {
	switch msg.(type) {
	case NextPageMsg:
		if m.Page < Page5 {
			m.Page++
			return m, nil
		}
	case PrevPageMsg:
		if m.Page > Page1 {
			m.Page--
			return m, nil
		}
	}
	var cmd tea.Cmd
	switch m.Page {
	case Page1:
		m.Form1, cmd = m.Form1.Update(msg)
	}
	return m, cmd
}

func (m InstallServiceModel) View() string {
	switch m.Page {
	case Page1:
		return m.Form1.View()
	case Page2:
		return m.Form2.View()
	case Page3:
		return m.Form3.View()
	case Page4:
		// TODO
		return "Loading..."
	case Page5:
		// TODO
		return "Done!"
	default:
		return "Uh Oh!"
	}
}
