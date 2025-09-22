package main

//go:generate go run -modfile=go.dev.mod builtin.generator.go -i builtin/ -o builtin.go

import (
	"os"
	"io/fs"
	"path/filepath"
	"strings"
	"log"
	"fmt"
	"errors"
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

	home, err := os.UserHomeDir()
	if err != nil {
		log.Fatalln(err)
	}

	config_dir := os.Getenv("XDG_CONFIG_HOME")
	if config_dir == "" {
		config_dir = filepath.Join(home, ".config")
	}
	config_dir = filepath.Join(config_dir, "swayq")

	if path, found := findModuleAt(name, config_dir); found {
		return path, nil
	} else if path, found := findModuleAt(name, filepath.Join(home, ".jq")); found {
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
	config_dir := os.Getenv("XDG_CONFIG_HOME")
	if config_dir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, err
		}
		config_dir = filepath.Join(home, ".config")
	}
	config_dir = filepath.Join(config_dir, "swayq")

	config_dir, err := filepath.EvalSymlinks(config_dir)
	if err != nil {
		log.Fatalln(err)
	}

	var modules []moduleLoc
	filepath.WalkDir(config_dir, func(path string, info fs.DirEntry, err error) error {
		if info != nil && !info.IsDir() && strings.HasSuffix(path, ".jq") {
			relpath, err := filepath.Rel(config_dir, path)
			if err != nil {
				return err
			}
			modules = append(modules, moduleLoc{
				relpath[:len(relpath)-3],
				filepath.Join(config_dir, relpath),
			})
		}
		return nil
	})

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
