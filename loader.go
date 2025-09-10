package main

//go:generate go run -modfile=go.dev.mod builtin.generator.go -i builtin/ -o builtin.go

import (
	"os"
	"path/filepath"
	"strings"
	"log"
	"fmt"
	"errors"
	"io/ioutil"
	"github.com/itchyny/gojq"
)

type swayqModuleLoader struct {
	base *gojq.Query
}

func (l *swayqModuleLoader) LoadInitModules() ([]*gojq.Query, error) {
	if l.base == nil {
		return []*gojq.Query{}, nil
	} else {
		modules := make([]*gojq.Query, 1)
		modules[0] = l.base
		return modules, nil
	}
}

func (l *swayqModuleLoader) LoadModule(name string) (*gojq.Query, error) {
	if strings.HasPrefix(name, "builtin/") {
		builtin := LoadBuiltin(name[8:])
		if builtin != nil {
			return builtin, nil
		} else {
			return nil, errors.New(fmt.Sprintf("No builtin named %v", name[8:]))
		}
	}

	path, err := findModulePath(name)
	if err != nil {
		builtin := LoadBuiltin(name)
		if builtin == nil {
			return nil, err
		} else {
			return builtin, nil
		}
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	query, err := gojq.Parse(string(data))
	if err != nil {
		return nil, err
	}

	return query, nil
}

func findModuleAt(filename string, dir string) (string, bool) {
	path := filepath.Join(dir, filename)
	if _, err := os.Stat(path); err == nil {
		return path, true
	}
	return path, false
}

func findModulePath(name string) (string, error) {
	if filepath.IsAbs(name) {
		return name, nil
	}

	if !strings.HasSuffix(name, ".jq") {
		name = name + ".jq"
	}

	// Check current working directory
	cwd, err := os.Getwd()
	if err != nil {
		log.Fatalln(err)
	} else if path, found := findModuleAt(name, cwd); found {
		return path, nil
	}

	// Check the home directory config files
	home, err := os.UserHomeDir()
	if err != nil {
		log.Fatalln(err)
	} else if path, found := findModuleAt(name, filepath.Join(home, ".config", "swayq")); found {
		return path, nil
	} else if path, found := findModuleAt(name, filepath.Join(home, ".config", "i3q")); found {
		return path, nil
	} else if path, found := findModuleAt(name, filepath.Join(home, ".jq")); found {
		return path, nil
	} 

	// Check the executable's directory
	exe, err := os.Executable()
	if err != nil {
		log.Fatalln(err)
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		log.Fatalln(err)
	} else if path, found := findModuleAt(name, filepath.Join(filepath.Dir(exe), "..", "lib", "jq")); found {
		return path, nil
	}

	msg := fmt.Sprintf("Could not find module %v", name)
	return "", errors.New(msg)
}

type moduleLoc struct {
	name string
	location string
}

func listModules() ([]moduleLoc, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return nil, err
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	paths := make([]string, 3)
	paths[0] = cwd
	paths[1] = filepath.Join(home, ".config", "swayq")
	paths[2] = filepath.Join(home, ".config", "i3q")

	var modules []moduleLoc
	for _, path := range paths {
		files, err := ioutil.ReadDir(path)
		if err != nil {
			continue
		}
		for _, file := range files {
			name := file.Name()
			ext := filepath.Ext(name)
			if file.IsDir() || ext != ".jq" {
				continue
			}
			modules = append(modules, moduleLoc{
				strings.TrimSuffix(name, ext),
				filepath.Join(path, name),
			})
		}
	}

	builtins := listBuiltins()
	for _, builtin := range builtins {
		for _, b := range modules {
			if b.name == builtin {
				continue
			}
		}
		modules = append(modules, moduleLoc{
			builtin,
			filepath.Join("builtin/", builtin),
		})
	}
	return modules, nil
}
