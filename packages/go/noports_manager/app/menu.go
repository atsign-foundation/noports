package app

import (
	"fmt"
	"io"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
)

type (
	MenuIdx int
)

type (
	MenuItem struct {
		label   string
		menuIdx MenuIdx
	}
	MenuItemDelegate struct{}
)

func CreateMenu(items []list.Item, width int) list.Model {
	l := list.New(items, MenuItemDelegate{}, width, len(items)+8)

	l.Title = "What would you like to do?"
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)
	l.SetShowPagination(false)
	l.Styles.HelpStyle = helpStyle

	// Set Up Help for Key Binds

	selectKey := key.Binding{}
	selectKey.SetKeys("enter")
	selectKey.SetEnabled(true)
	selectKey.SetHelp("enter", "select")
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{selectKey}
	}
	l.AdditionalFullHelpKeys = func() []key.Binding {
		return []key.Binding{selectKey}
	}

	l.Styles.Title = titleStyle
	return l
}

func (i MenuItem) FilterValue() string                             { return "" }
func (d MenuItemDelegate) Height() int                             { return 1 }
func (d MenuItemDelegate) Spacing() int                            { return 0 }
func (d MenuItemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }
func (d MenuItemDelegate) Render(w io.Writer, m list.Model, index int, listItem list.Item) {
	i, ok := listItem.(MenuItem)
	if !ok {
		return
	}

	str := fmt.Sprintf("%d. %s", i.menuIdx, i.label)
	fn := itemStyle.Render
	if index == m.Index() {
		fn = func(s ...string) string {
			return selectedItemStyle.Render("> " + strings.Join(s, " "))
		}
	}

	fmt.Fprint(w, fn(str))
}
