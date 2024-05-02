package command

import "time"

const WelcomeMessage = `Welcome to the NoPorts Trial environment!

Hint: To see the full controls of this application, press "?"

This environment allows you to test out NoPorts before doing device setup. If you're seeing this message, your client was set up correctly!

We have a few cool tricks you can try while you are here:

#1 - List out all the network interfaces
#2 - Run nmap to scan the public interface for open ports

Combined, these will show you that there aren't any inbound ports open on this machine. We've taken a number of precautions to ensure that we minimize the network attack surface when you use NoPorts, while also making it as easy to use as possible. If you're curious about how the technology works, or you want to learn more about how we handle security, please visit our site:

https://www.noports.com/sshnp-how-it-works
`

type WelcomeCmd struct{}

func (c WelcomeCmd) FilterValue() string { return "Show the Welcome Message" }
func (c WelcomeCmd) Title() string       { return "Show the Welcome Message" }
func (c WelcomeCmd) Description() string { return "(Run to see it again)" }
func (c WelcomeCmd) Run(done chan int) (chan string, error) {
	ch := make(chan string, 100)

	go func() {
		ch <- WelcomeMessage
		time.Sleep(250 * time.Millisecond) // Give the pipe enough time to clear - also prevents clients from running > 4 commands / second
		done <- 0
	}()

	return ch, nil
}
