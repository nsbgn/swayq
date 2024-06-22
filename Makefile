GO := /usr/lib/go-1.21/bin/go
BIN := i3jq
REVISION = $(shell git rev-parse --short HEAD)
LDFLAGS = "-s -w -X 'main.Version=$(REVISION)'"

BUILTIN_JQ = $(wildcard builtin*.jq)

.PHONY: all
all: build

.PHONY: build
build: $(BIN)

.PHONY: clean
clean:
	rm -rf $(BIN)
	go clean

.PRECIOUS: builtin.go
builtin.go: _tools/gen_builtin.go ${BUILTIN_JQ}
	$(GO) run $^

%: %.go $(wildcard *.go) builtin.go
	$(GO) build -ldflags=$(LDFLAGS) -o $@ $^
