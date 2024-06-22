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
	var fileFlag = flag.String("f", "", "Read query from file")
	var quietFlag = flag.Bool("q", false, "Do not print values")
	var helpFlag = flag.Bool("h", false, "Show help")
	flag.Parse()
	var args = flag.Args()

	if *helpFlag {
		fmt.Fprintf(os.Stderr, "Usage: %s [OPTION...] [QUERY] [ARGS...]\n\n", os.Args[0])
		flag.PrintDefaults()
		os.Exit(0)
	}

	loader := i3jqModuleLoader{}

	var query_file *gojq.Query
	if *fileFlag != "" {
		q, err := loader.LoadModule(*fileFlag)
		if err != nil {
			log.Fatalln(err)
		}
		query_file = q
	}

	var query_arg *gojq.Query
	if len(args) > 0 {
		q, err := gojq.Parse(args[0])
		if err != nil {
			log.Fatalln(err)
		}
		query_arg = q
	}

	var query *gojq.Query
	if query_arg != nil {
		if query_file != nil {
			loader.base = query_file
		}
		query = query_arg
	} else if query_file != nil {
		query = query_file
	} else {
		query = &gojq.Query{Term: &gojq.Term{Type: gojq.TermTypeIdentity}}
	}

	if query != nil {
		code, err := gojq.Compile(query,
			gojq.WithModuleLoader(&loader),
			gojq.WithIterFunction("_i3jq", 3, 3, func(_ any, xs []any) gojq.Iter {
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

				iter, err := i3jq_ipc(messageType, payload, keepAlive)
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

		iter := code.Run(nil)
		for {
			val, ok := iter.Next()
			if !ok {
				break
			}
			if err, ok := val.(error); ok {
				log.Fatalln(err)
			}
			if !*quietFlag {
				output, err := gojq.Marshal(val)
				if err != nil {
					log.Fatalln(err)
				}
				fmt.Println(string(output))
			}
		}
	}
}
