package app

import "github.com/charmbracelet/bubbles/textinput"

type (
	FormValidator func(input FormInput) (is_valid bool, error *string)
	api           struct {
		DeviceName textinput.ValidateFunc
		Atsign     textinput.ValidateFunc
	}
)

var FormValidators api = api{
	DeviceName: deviceName,
	Atsign:     atsign,
}

func atsign(input string) error {
	// TODO
	return nil
}

func deviceName(input string) error {
	// TODO
	return nil
}
