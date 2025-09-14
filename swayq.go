package main

import (
	"os"
	"fmt"
	"log"
	"flag"
	"strings"
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

	loader := swayqModuleLoader{}
	completions := os.Getenv("SWAYQ_COMPLETIONS") != ""

	if len(args) == 0 || completions {
		modules, err := listModules()
		if err != nil {
			log.Fatalln(err)
			os.Exit(1)
		}

		if completions {
			for _, module := range modules {
				fmt.Println(module.name)
			}
			os.Exit(0)
		}

		fmt.Println("Available modules:")
		for _, module := range modules {
			q, err := loader.LoadModule(module.name)
			if err != nil {
				continue
			}

			fmt.Print("\u001b[1m", module.name, "\u001b[0m")
			if q.Meta != nil {
				descrAny := q.Meta.ToValue()["description"]
				if descrStr, ok := descrAny.(string); ok {
					fmt.Print("\n    ", descrStr)
				}
			}
			fmt.Println()
		}
		os.Exit(0)
	}


	var query *gojq.Query
	query, err := loader.LoadModule(args[0])
	if err != nil {
		log.Fatalln(err)
	}
	loader.base = query

	// Check if the module sets a query (rather than only function
	// definitions). If it does, we execute that query and treat all
	// non-flag arguments as $ARGS. If it doesn't, then the first
	// argument is our query and the rest of the arguments are our
	// $ARGS.
	idx_args := 1
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

	// Pass command-line arguments through.
	kwargs := make(map[string]any)
	nargs := make([]any, 0)

	// In the simple case, all arguments are positional arguments and any
	// additional parsing is on the user. However, there is also experimental
	// argument-parsing that is currently quite simplistic and can be enabled
	// by setting any value for `args` in the module's metadata. kwargs will
	// lose ordering information, all short-form arguments are simple flags,
	// and only long-form arguments can be given a string value with `=`.
	// Repeating arguments has no effect at the moment.
	// TODO for the future: flesh out this argument parsing, so that we can
	// use it to automatically generate the help text, completions, and 
	// do argument validation.
	// (!) It will *not* be backwards compatible, so this should be considered
	// experimental.
	if query.Meta != nil && query.Meta.ToValue()["args"] != nil {
		doubledash := false
		for _, arg := range args[idx_args:] {
			if !doubledash && arg[0] == '-' {
				if len(arg) == 1 {
					continue
				} else if arg == "--" {
					doubledash = true
				} else {
					if arg[1] == '-' {
						j := strings.IndexByte(arg, '=')
						if j > 0 {
							kwargs[arg[2:j]] = []any{arg[j+1:]}
						} else {
							kwargs[arg[2:]] = []any{""}
						}
					} else {
						for _, char := range arg[1:] {
							kwargs[string(char)] = 1
						}
					}
				}
			} else {
				nargs = append(nargs, arg)
			}
		}
	} else {
		for _, arg := range args[idx_args:] {
			nargs = append(nargs, arg)
		}
	}
	varArgs := map[string]any{
		"module": args[0],
	 	"named": kwargs,
	 	"positional": nargs,
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
