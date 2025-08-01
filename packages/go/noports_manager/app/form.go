package app

import (
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

type Form struct {
	onSubmit tea.Cmd
	onBack   tea.Cmd
	inputs   []FormInput
	focused  int
}

func CreateForm(inputs []FormInput, onSubmit tea.Cmd, onBack tea.Cmd) Form {
	for _, input := range inputs {
		input.Prompt = ">"
	}
	return Form{
		inputs:   inputs,
		focused:  0,
		onSubmit: onSubmit,
		onBack:   onBack,
	}
}

func (f Form) Init() tea.Cmd {
	return textinput.Blink
}

func (f Form) MaxFocus() int {
	return len(f.inputs) - 1
}

func (f Form) Focused() *FormInput {
	return &f.inputs[f.focused]
}

func (f Form) FocusNext() (Form, tea.Cmd) {
	if f.focused < f.MaxFocus() {
		f.Focused().Blur()
		f.focused++
		cmd := f.Focused().Focus()
		return f, cmd
	}
	return f, nil
}

func (f Form) FocusPrev() (Form, tea.Cmd) {
	if f.focused > 0 {
		f.Focused().Blur()
		f.focused--
		cmd := f.Focused().Focus()
		return f, cmd
	}
	return f, nil
}

func (f Form) Update(msg tea.Msg) (Form, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "esc":
			return f, f.onBack
		case "tab":
			return f.FocusNext()
		case "shift+tab":
			return f.FocusPrev()
		case "enter":
			if f.focused == f.MaxFocus() {
				errors := f.Validate()
				if len(errors) == 0 {
					return f, f.onSubmit
				}
			}
			return f.FocusNext()
		}
	}
	var cmd tea.Cmd
	cmds := []tea.Cmd{}
	if !f.Focused().Focused() {
		cmd = f.Focused().Focus()
		if cmd != nil {
			cmds = append(cmds, cmd)
		}
	}
	f.Focused().TextInput, cmd = f.Focused().Update(msg)
	if cmd != nil {
		cmds = append(cmds, cmd)
	}
	if len(cmds) == 0 {
		return f, nil
	}
	return f, tea.Batch(cmds...)
}

func (f Form) View() string {
	s := strings.Builder{}

	for _, input := range f.inputs {
		s.WriteString(input.Label)
		s.WriteRune(':')
		s.WriteRune('\n')
		s.WriteString(input.View())
		s.WriteRune('\n')
	}

	return s.String()
}

func (f Form) Validate() []error {
	errors := []error{}
	for _, el := range f.inputs {
		err := el.Validate(el.Value())
		if err != nil {
			errors = append(errors, err)
		}
	}
	return errors
}
