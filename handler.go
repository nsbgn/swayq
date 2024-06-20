// A handler maps each [eventType] to compiled [gojq.Code], to be executed in 
// case the corresponding event occurs
type HandlerMap [eventN]*gojq.Code

func GetHandlerMap(q *gojq.Query) (*HandlerMap, error) {
	var hm = new(HandlerMap)

	re := regexp.MustCompile(`on_(.+)_event`)
	for _, fn := range q.FuncDefs {
		match := re.FindStringSubmatch(fn.Name)
		if match != nil {
			if len(fn.Args) != 0 {
				msg := fmt.Sprintf("event handler %v must have no arguments", fn.Name)
				return nil, errors.New(msg)
			}

			t, err := eventFromString(match[1])
			if err != nil {
				return nil, err
			}

			// Make a query that just calls the handler, and copy the original 
			// query's function definitions into it
			h, err := gojq.Parse(match[0])
			if err != nil {
				return nil, err
			}
			h.Imports = q.Imports
			h.FuncDefs = q.FuncDefs

			code, err := gojq.Compile(h)
			if err != nil {
				return nil, err
			}

			hm[t] = code
		}
	}
	return hm, nil
}
