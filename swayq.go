package main

import (
	"os"
	"fmt"
	"log"
	"flag"
	"github.com/itchyny/gojq"
)


func main() {
	var quietFlag = flag.Bool("q", false, "Do not print values")
	var rawFlag = flag.Bool("r", true, "Print raw values")
	var rawInputFlag = flag.Bool("R", true, "Read standard input as raw text lines")
	var helpFlag = flag.Bool("h", false, "Show help")
	flag.Parse()
	var args = flag.Args()

	if *helpFlag {
		fmt.Fprintf(os.Stderr, "Usage: %s [OPTION...] [MODULE] [ARGS...]\n\n", os.Args[0])
		flag.PrintDefaults()
		os.Exit(0)
	}
	if len(args) == 0 {
		fmt.Println("Please provide a module.")
		os.Exit(0)
	}

	loader := swayqModuleLoader{}

	var query *gojq.Query
	query, err := loader.LoadModule(args[0])
	if err != nil {
		log.Fatalln(err)
	}
	idx_args := 1
	loader.base = query

	// Check if the module sets a query (rather than only function
	// definitions). If it does, we execute that query and treat all
	// non-flag arguments as $ARGS. If it doesn't, then the first
	// argument is our query and the rest of the arguments are our
	// $ARGS.
	if query.Term == nil && query.Left == nil {
		if len(args) > 1 {
			idx_args = idx_args + 1
			q, err := gojq.Parse(args[1])
			if err != nil {
				log.Fatalln(err)
			}
			query = q
		} else {
			log.Fatalln("no query provided")
		}
	}

	// Pass command-line arguments through
	nargs := len(args) - idx_args
	if (nargs < 0) {
		nargs = 0
	}
	positional := make([]any, nargs)
	if (nargs > 0) {
		for i, arg := range args[idx_args:] {
			positional[i] = arg
		}
	}
	varArgs := map[string]any{
	 	"named": map[string]any{},
	 	"positional": positional,
	 }

	var inputIter gojq.Iter
	if *rawInputFlag {
		inputIter = newRawInputIter(os.Stdin)
	} else {
		inputIter = newJSONInputIter(os.Stdin)
	}

	if query != nil {
		code, err := compile(query, &loader, inputIter)
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
