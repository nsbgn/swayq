package main

import (
	"os"
	"path/filepath"
	"strings"
	"log"
	"fmt"
	"errors"
	"github.com/itchyny/gojq"
)

type i3jqModuleLoader struct {
	base *gojq.Query
}

func (l *i3jqModuleLoader) LoadInitModules() ([]*gojq.Query, error) {
	m, _ := gojq.Parse(`
		def run_command(payload): _i3jq(0; payload);
		def get_workspaces: _i3jq(1);
		def subscribe(payload): _i3jq(2; payload | tostring; true);
		def get_outputs: _i3jq(3);
		def get_tree: _i3jq(4);
		def get_marks: _i3jq(5);
		def get_bar_config(payload): _i3jq(6; payload);
		def get_bar_config: get_bar_config("");
		def get_version: _i3jq(7);
		def get_binding_modes: _i3jq(8);
		def get_config: _i3jq(9);
		def send_tick: _i3jq(10);
		def sync(payload): _i3jq(11; payload);
		def get_binding_state(payload): _i3jq(12; payload);
	`)

	modules := make([]*gojq.Query, 1)
	modules[0] = m
	if l.base != nil {
		modules = append(modules, l.base)
	}
	return modules, nil
}

func (l *i3jqModuleLoader) LoadModule(name string) (*gojq.Query, error) {
	path, err := findModulePath(name)
	if err != nil {
		return nil, err
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
	} else if path, found := findModuleAt(name, filepath.Join(home, ".jq", "i3jq")); found {
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
	} else if path, found := findModuleAt(name, filepath.Join(filepath.Dir(exe))); found {
		return path, nil
	}

	msg := fmt.Sprintf("Could not find module %v", name)
	return "", errors.New(msg)
}


