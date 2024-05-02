package app

import "github.com/charmbracelet/bubbles/key"

type AppKeyMap struct{}

var (
	upKey = key.NewBinding(
		key.WithKeys("up", "k"),
		key.WithHelp("↑/k", "up"),
	)
	downKey = key.NewBinding(
		key.WithKeys("down", "j"),
		key.WithHelp("↓/j", "down"),
	)
	runKey = key.NewBinding(
		key.WithKeys("enter"),
		key.WithHelp("enter", "run"),
	)
	moreKey = key.NewBinding(
		key.WithKeys("?"),
		key.WithHelp("?", "more"),
	)
	lessKey = key.NewBinding(
		key.WithKeys("?"),
		key.WithHelp("?", "close help"),
	)
	quitKey = key.NewBinding(
		key.WithKeys("q", "esc"),
		key.WithHelp("q", "quit"),
	)
	scrollUpKey = key.NewBinding(
		key.WithKeys("ctrl+u"),
		key.WithHelp("ctrl+u", "scroll up"),
	)
	scrollDownKey = key.NewBinding(
		key.WithKeys("ctrl+d"),
		key.WithHelp("ctrl+d", "scroll down"),
	)
)

var (
	short = []key.Binding{
		upKey, downKey, runKey, quitKey, moreKey,
	}
	full = [][]key.Binding{
		{upKey, downKey},
		{scrollUpKey, scrollDownKey},
		{runKey, quitKey},
		{lessKey},
	}
	fullOnly = [][]key.Binding{
		{upKey, downKey},
		{runKey},
		{scrollUpKey, scrollDownKey},
		{quitKey},
	}
	FullHelpHeight     = 2
	FullOnlyHelpHeight = 2
)

func (a AppKeyMap) ShortHelp() []key.Binding {
	return short
}

func (a AppKeyMap) FullHelp() [][]key.Binding {
	return full
}

func (a AppKeyMap) FullHelpOnly() [][]key.Binding {
	return fullOnly
}
