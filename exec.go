package main

import (
	"errors"
	"os/exec"
	"bufio"

	"github.com/itchyny/gojq"
)

// This is an MVP. I don't think this is the best way to do things; it's just
// something that works for now. Suggestions welcome ;)

type channelIterator struct {
	ch *chan map[string]any
}

func (iter channelIterator) Next() (any, bool) {
	obj := <-*iter.ch
	return obj, true
}

func execToChannel(args any, i int, ch *chan map[string]any) error {
	argsArrayAny, ok := args.([]any)
	if !ok {
		return errors.New("must be an array")
	}

	argsArrayStr := make([]string, len(argsArrayAny))
	for i, arg := range argsArrayAny {
		str, ok := arg.(string)
		if !ok {
			return errors.New("elements of the array must be a string")
		}
		argsArrayStr[i] = str
	}

	cmd := exec.Command(argsArrayStr[0], argsArrayStr[1:]...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		*ch <- map[string]any{
			"channel": i,
			"error": err.Error(),
		}
		return err
	}

	err = cmd.Start()
	if err != nil {
		*ch <- map[string]any{
			"channel": i,
			"error": err.Error(),
		}
		return err
	}

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		*ch <- map[string]any{
			"channel": i,
			"text": line,
		}
	}

	if err := scanner.Err(); err != nil {
		*ch <- map[string]any{
			"channel": i,
			"error": err.Error(),
		}
		return err
	}

	if err := cmd.Wait(); err != nil {
		*ch <- map[string]any{
			"channel": i,
			"error": err.Error(),
		}
		return err
	}
	return nil
}

// Run one or more external processes, and return an iterator that
// goes through each line in each process and returns objects
// of the form `{channel: 1, text: "line"}`
func funcExecMultiplex(_ any, xs []any) gojq.Iter {
	ch := make(chan map[string]any)
	for i, args := range xs {
		go execToChannel(args, i, &ch)
	}
	return channelIterator{&ch}
}
