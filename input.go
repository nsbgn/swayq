package main

// Portions of this file were taken from <https://github.com/itchyny/gojq/blob/main/cli/inputs.go>

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"os"
	"strings"

	"github.com/itchyny/gojq"
)

type inputReader struct {
	io.Reader
	file *os.File
	buf  *bytes.Buffer
}

func newInputReader(r io.Reader) *inputReader {
	if r, ok := r.(*os.File); ok {
		if _, err := r.Seek(0, io.SeekCurrent); err == nil {
			return &inputReader{r, r, nil}
		}
	}
	var buf bytes.Buffer
	return &inputReader{io.TeeReader(r, &buf), nil, &buf}
}

type jsonInputIter struct {
	next   func() (any, error)
	ir     *inputReader
	err    error
}

func newJSONInputIter(r io.Reader) gojq.Iter {
	ir := newInputReader(r)
	dec := json.NewDecoder(ir)
	dec.UseNumber()
	next := func() (v any, err error) { err = dec.Decode(&v); return }
	return &jsonInputIter{next: next, ir: ir}
}

func (i *jsonInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	v, err := i.next()
	if err != nil {
		if err == io.EOF {
			i.err = err
			return nil, false
		}
		i.err = errors.New("JSON parsing error in stdin")
		return i.err, true
	}
	if buf := i.ir.buf; buf != nil && buf.Len() >= 16*1024 {
		buf.Reset()
	}
	return v, true
}

func (i *jsonInputIter) Close() error {
	i.err = io.EOF
	return nil
}

type rawInputIter struct {
	r     *bufio.Reader
	err   error
}

func newRawInputIter(r io.Reader) gojq.Iter {
	return &rawInputIter{r: bufio.NewReader(r)}
}

func (i *rawInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	line, err := i.r.ReadString('\n')
	if err != nil {
		i.err = err
		if err != io.EOF {
			return err, true
		}
		if line == "" {
			return nil, false
		}
	}
	return strings.TrimSuffix(line, "\n"), true
}

func (i *rawInputIter) Close() error {
	i.err = io.EOF
	return nil
}
