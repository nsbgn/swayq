package main

import (
	"os"
	"log"
	"fmt"
	"sync"
	"time"
	"errors"
	"encoding/json"
	"github.com/itchyny/gojq"
)

func deepCopy(x any) (any, error) {
	var xCopy any
	xJson, err := json.Marshal(x)
	if err != nil {
		return nil, errors.New("error marshalling input")
	}
	err = json.Unmarshal(xJson, &xCopy)
	if err != nil {
		return nil, errors.New("error unmarshalling input")
	}
	return xCopy, nil
}

type channelIter struct {
	ch *chan any
	wg *sync.WaitGroup
}

func (iter channelIter) Next() (any, bool) {
	obj, ok := <-*iter.ch
	if !ok {
		return errors.New("channel was closed"), false
	}
	return obj, true
}

// Process a query and send result to channel
func eval(iter *channelIter, queryStr string, input any, loader gojq.ModuleLoader, inputIter gojq.Iter, varArgs any) {
	defer iter.wg.Done()

	query, err := gojq.Parse(queryStr)
	if err != nil {
		*iter.ch <- err
		return
	}
	code, err := compile(query, loader, inputIter, varArgs)
	if err != nil {
		*iter.ch <- err
		return
	}

	runIter := code.Run(input, varArgs)
	for {
		val, ok := runIter.Next()
		if !ok {
			break
		}
		*iter.ch <- val
	}
}

func compile(query *gojq.Query, loader gojq.ModuleLoader, inputIter gojq.Iter, varArgs any) (*gojq.Code, error) {
	varArgsCopy, err := deepCopy(varArgs)
	if err != nil {
		log.Fatalln(err)
	}
	return gojq.Compile(query,
		gojq.WithModuleLoader(loader),
		gojq.WithEnvironLoader(os.Environ),
		gojq.WithVariables([]string{"$ARGS"}),
		gojq.WithInputIter(inputIter),
		gojq.WithFunction("debug", 0, 0, funcDebug),
		gojq.WithFunction("stderr", 0, 0, funcStderr),
		gojq.WithIterFunction("sleep", 1, 1, funcSleep),
		gojq.WithIterFunction("_ipc", 4, 4, funcIpc),
		gojq.WithIterFunction("exec", 1, 1, funcExec),
		gojq.WithIterFunction("eval", 1, 1, func (x any, xs []any) gojq.Iter {

			xsArray, ok := xs[0].([]any)
			if !ok {
				return gojq.NewIter(errors.New("eval expects an array"))
			}

			ch := make(chan any)
			wg := sync.WaitGroup{}
			iter := channelIter{&ch, &wg}
			for _, query := range xsArray {
				wg.Add(1)

				// Parse argument as string
				queryString, ok := query.(string)
				if !ok {
					return gojq.NewIter(errors.New("a filter to be evaluated must be a string"))
				}

				xCopy, err := deepCopy(x)
				if err != nil {
					return gojq.NewIter(err)
				}

				go eval(&iter, queryString, xCopy, loader, inputIter, varArgsCopy)
			}
			go func(){
				wg.Wait()
				close(ch)
			}()
			return iter
		}),
	)
}

func funcIpc(_ any, xs []any) gojq.Iter {
	socket, ok := xs[0].(string)
	if !ok {
		return gojq.NewIter(errors.New("socket param must be a string"))
	}

	messageType, ok := xs[1].(int)
	if !ok {
		return gojq.NewIter(errors.New("messageType param must be an int"))
	}

	var payload *string = nil
	if str, ok := xs[2].(string); ok {
		payload = &str
	} else if xs[2] != nil {
		return gojq.NewIter(errors.New("payload param must be a string"))
	}

	keepAlive, ok := xs[3].(bool)
	if !ok {
		return gojq.NewIter(errors.New("keepAlive param must be a bool"))
	}

	iter, err := swayq_ipc(&socket, messageType, payload, keepAlive)
	if err != nil {
		return gojq.NewIter(err)
	} else {
		return iter
	}
}

func funcDebug(v any, _ []any) any { // FIXME
	debug, err := gojq.Marshal([]any{"DEBUG:", v})
	if err == nil {
		fmt.Fprintln(os.Stderr, string(debug))
	}
	return v
}

func funcStderr(v any, _ []any) any { // FIXME
	item, err := gojq.Marshal(v)
	if err == nil {
		fmt.Fprint(os.Stderr, string(item))
	}
	return v
}

func funcSleep(v any, xs []any) gojq.Iter {
	s, ok := xs[0].(int)
	if !ok {
		return gojq.NewIter(errors.New("sleep must have an integer argument"))
	}
	time.Sleep(time.Duration(s) * time.Second)
	return gojq.NewIter()
}
