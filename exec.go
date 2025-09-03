package main

import (
	"errors"
	"os/exec"
	"bufio"

	"github.com/itchyny/gojq"
)

type execIter struct {
	cmd *exec.Cmd
	scanner *bufio.Scanner
}

func (iter execIter) Next() (any, bool) {
	if iter.scanner.Scan() {
		return iter.scanner.Text(), true
	}
	
	if err := iter.scanner.Err(); err != nil {
		return err, false
	}

	if err := iter.cmd.Wait(); err != nil {
		return err, false
	}

	return nil, false
}

func funcExec(_ any, xs []any) gojq.Iter {
	argsArrayAny, ok := xs[0].([]any)
	if !ok {
		return gojq.NewIter(errors.New("exec expects array input"))
	}

	argsArrayStr := make([]string, len(argsArrayAny))
	for i, arg := range argsArrayAny {
		str, ok := arg.(string)
		if !ok {
			return gojq.NewIter(errors.New("elements of the array must be a string"))
		}
		argsArrayStr[i] = str
	}

	cmd := exec.Command(argsArrayStr[0], argsArrayStr[1:]...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return gojq.NewIter(err)
	}

	err = cmd.Start()
	if err != nil {
		return gojq.NewIter(err)
	}

	scanner := bufio.NewScanner(stdout)

	return execIter{cmd, scanner}
}
