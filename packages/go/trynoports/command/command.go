package command

type (
	RunnerWithDone interface {
		Run(done chan int) (chan string, error)
	}

	// The full interface that items must implement
	CommandListEntry interface {
		Run(done chan int) (chan string, error)
	}
)
