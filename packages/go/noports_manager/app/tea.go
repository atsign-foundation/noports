package app

import tea "github.com/charmbracelet/bubbletea"

type (
	page        int
	NextPageMsg struct{ tea.Msg }
	PrevPageMsg struct{ tea.Msg }
)

func NextPageCmd() tea.Msg {
	return NextPageMsg{}
}

func PrevPageCmd() tea.Msg {
	return PrevPageMsg{}
}
