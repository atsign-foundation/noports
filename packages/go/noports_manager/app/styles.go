package app

import (
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle        = lipgloss.NewStyle().MarginLeft(2)
	itemStyle         = lipgloss.NewStyle().PaddingLeft(4)
	selectedItemStyle = lipgloss.NewStyle().PaddingLeft(2).Foreground(lipgloss.Color("170"))
	helpStyle         = list.DefaultStyles().HelpStyle.PaddingLeft(4).PaddingBottom(1)
	focusedStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
	errorStyle        = lipgloss.NewStyle().Foreground(lipgloss.Color("#ff0000"))
	blurredStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("240"))
)
