package app

import (
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

type (
	TextInput = textinput.Model
)

type FormInput struct {
	Label string
	TextInput
}

func (f FormInput) Blur() {
	f.TextInput.Blur()
	f.PromptStyle = blurredStyle
	f.TextStyle = blurredStyle
}

func (f FormInput) Focus() tea.Cmd {
	f.PromptStyle = focusedStyle
	f.TextStyle = focusedStyle
	return f.TextInput.Focus()
}
