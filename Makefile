BIN := i3jq
REVISION = $(shell git rev-parse --short HEAD)
LDFLAGS = "-s -w -X 'main.Version=$(REVISION)'"

BUILTIN_JQ = $(wildcard builtin_*.jq)
BUILTIN_GO = $(patsubst %.jq,%.go,${BUILTIN_JQ})

.PHONY: all
all: build

.PHONY: build
build: $(BIN)

.PHONY: clean
clean:
	rm -rf $(BIN)
	go clean

.PRECIOUS: builtin_%.go
builtin_%.go: builtin_%.jq
	go run _tools/gen_builtin.go -n $(patsubst builtin_%.go,%,$@) -i $< -o $@

%: %.go $(wildcard *.go) ${BUILTIN_GO}
	go build -ldflags=$(LDFLAGS) -o $@ $^
