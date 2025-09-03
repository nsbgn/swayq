package main

import (
	"os"
	"errors"
	"github.com/itchyny/gojq"
)

func compile(query *gojq.Query, loader gojq.ModuleLoader, inputIter gojq.Iter) (*gojq.Code, error) {
	return gojq.Compile(query,
		gojq.WithModuleLoader(loader),
		gojq.WithEnvironLoader(os.Environ),
		gojq.WithVariables([]string{"$ARGS"}),
		gojq.WithInputIter(inputIter),
		gojq.WithIterFunction("exec_experimental", 1, 30, funcExecMultiplex),
		gojq.WithIterFunction("_ipc", 3, 3, funcIpc),
	)
}

func funcIpc(_ any, xs []any) gojq.Iter {
	messageType, ok0 := xs[0].(int)
	if !ok0 {
		return gojq.NewIter(errors.New("messageType param must be an int"))
	}

	keepAlive, ok2 := xs[2].(bool)
	if !ok2 {
		return gojq.NewIter(errors.New("keepAlive param must be a bool"))
	}

	var payload *string = nil
	if str, ok := xs[1].(string); ok {
		payload = &str
	} else if xs[1] != nil {
		return gojq.NewIter(errors.New("payload param must be a string"))
	}

	iter, err := swayq_ipc(messageType, payload, keepAlive)
	if err != nil {
		return gojq.NewIter(err)
	} else {
		return iter
	}
}
