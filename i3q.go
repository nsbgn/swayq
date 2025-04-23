package main

import (
	"os"
	"fmt"
	"log"
	"flag"
	"errors"
	"github.com/itchyny/gojq"
)


func main() {
	var quietFlag = flag.Bool("q", false, "Do not print values")
	var rawFlag = flag.Bool("r", true, "Print raw values")
	var helpFlag = flag.Bool("h", false, "Show help")
	flag.Parse()
	var args = flag.Args()

	if *helpFlag {
		fmt.Fprintf(os.Stderr, "Usage: %s [OPTION...] [MODULE] [QUERY] [ARGS...]\n\n", os.Args[0])
		flag.PrintDefaults()
		os.Exit(0)
	}

	loader := i3qModuleLoader{}

	var query_path = "default"
	if len(args) > 0 {
		query_path = args[0]
	}
	q, err := loader.LoadModule(query_path)
	if err != nil {
		log.Fatalln(err)
	}
	var query_file *gojq.Query
	query_file = q

	var query_arg *gojq.Query
	if len(args) > 1 {
		q, err := gojq.Parse(args[1])
		if err != nil {
			log.Fatalln(err)
		}
		query_arg = q
	}

	var query *gojq.Query
	if query_arg != nil {
		loader.base = query_file
		query = query_arg
	} else {
		query = query_file
	}

	// Pass command-line arguments through
	nargs := len(args) - 2
	if (nargs < 0) {
		nargs = 0
	}
	positional := make([]any, nargs)
	if (nargs > 0) {
		for i, arg := range args[2:] {
			positional[i] = arg
		}
	}
	varArgs := map[string]any{
	 	"named": map[string]any{},
	 	"positional": positional,
	 }

	if query != nil {
		code, err := gojq.Compile(query,
			gojq.WithModuleLoader(&loader),
			gojq.WithEnvironLoader(os.Environ),
			gojq.WithVariables([]string{"$ARGS"}),
			gojq.WithIterFunction("_internal", 3, 3, func(_ any, xs []any) gojq.Iter {
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

				iter, err := i3q_ipc(messageType, payload, keepAlive)
				if err != nil {
					return gojq.NewIter(err)
				} else {
					return iter
				}
			}),
		)
		if err != nil {
			log.Fatalln(err)
		}

		iter := code.Run(nil, varArgs)
		for {
			val, ok := iter.Next()
			if !ok {
				break
			}
			if err, ok := val.(error); ok {
				log.Fatalln(err)
			}
			if !*quietFlag {
				if str, ok := val.(string); (*rawFlag) && ok {
					fmt.Println(str)
				} else {
					output, err := gojq.Marshal(val)
					if err != nil {
						log.Fatalln(err)
					}
					fmt.Println(string(output))
				}
			}
		}
	}
}
