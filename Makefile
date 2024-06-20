BIN := i3jq
REVISION = $(shell git rev-parse --short HEAD)
LDFLAGS = "-s -w -X 'main.Version=$(REVISION)'"

.PHONY: all
all: build

.PHONY: build
build: $(BIN)

.PHONY: clean
clean:
	rm -rf $(BIN)
	go clean

%: %.go $(wildcard *.go)
	go build -ldflags=$(LDFLAGS) -o $@ $^
