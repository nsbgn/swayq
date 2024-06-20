package main

import (
	"fmt"
	"errors"
)

type eventType uint32

// Event types; cf <https://i3wm.org/docs/ipc.html#_events>
const (
	eventWorkspace eventType = 0
	eventOutput = 1
	eventMode = 2
	eventWindow = 3
	eventBarconfigUpdate = 4
	eventBinding = 5
	eventShutdown = 6
	eventTick = 7
)
const eventN = 8

func (t eventType) String() string {
	switch t {
	case eventWorkspace:
		return "workspace"
	case eventOutput:
		return "output"
	case eventMode:
		return "mode"
	case eventWindow:
		return "window"
	case eventBarconfigUpdate:
		return "barconfig_update"
	case eventBinding:
		return "binding"
	case eventShutdown:
		return "shutdown"
	case eventTick:
		return "tick"
	default:
		panic("invalid eventType")
	}
}

func eventFromString(t string) (eventType, error) {
	switch t {
	case "workspace":
		return eventWorkspace, nil
	case "output":
		return eventOutput, nil
	case "mode":
		return eventMode, nil
	case "window":
		return eventWindow, nil
	case "barconfig_update":
		return eventBarconfigUpdate, nil
	case "binding":
		return eventBinding, nil
	case "shutdown":
		return eventShutdown, nil
	case "tick":
		return eventTick, nil
	default:
		msg := fmt.Sprintf("unknown event string %v", t)
		return eventWorkspace, errors.New(msg)
	}
}
