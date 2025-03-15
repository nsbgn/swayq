PREFIX?=/usr/local
GO?=$(word 1,$(wildcard /usr/lib/go-1.21/bin/go) $(shell which go))
REVISION=$(shell git rev-parse --short HEAD)
LDFLAGS="-s -w -X 'main.Version=$(REVISION)'"

BUILTIN_JQ = $(wildcard builtin/*.jq)

.PHONY: all
all: build

.PHONY: build
build: i3jq

.PHONY: clean
clean:
	rm -rf i3jq builtin.go
	go clean

.PHONY: install
install: i3jq
	mkdir -p ${PREFIX}/bin/
	install -m755 i3jq ${PREFIX}/bin/
	ln -sf ${PREFIX}/bin/i3jq ${PREFIX}/bin/swayjq

.PHONY: uninstall
uninstall:
	rm -rf ${PREFIX}/bin/i3jq ${PREFIX}/bin/swayjq

.PRECIOUS: builtin.go
builtin.go: builtin.generator.go ${BUILTIN_JQ}
	$(GO) generate

%: %.go $(filter-out builtin.generator.go,$(wildcard *.go)) builtin.go
	$(GO) build -ldflags=$(LDFLAGS) -o $@ $^
