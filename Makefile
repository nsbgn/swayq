PREFIX?=/usr/local
GO?=$(word 1,$(wildcard /usr/lib/go-1.21/bin/go) $(shell which go))
BIN:=i3jq
REVISION=$(shell git rev-parse --short HEAD)
LDFLAGS="-s -w -X 'main.Version=$(REVISION)'"

BUILTIN_JQ = $(wildcard builtin/*.jq)

.PHONY: all
all: build

.PHONY: build
build: $(BIN)

.PHONY: clean
clean:
	rm -rf $(BIN) builtin.go
	go clean

.PHONY: install
install: i3jq
	mkdir -p ${PREFIX}/bin/
	install -m755 i3jq ${PREFIX}/bin/

.PHONY: install-contrib
install-contrib:
	mkdir -p ${PREFIX}/lib/jq/i3/layout/
	install -m644 contrib/*.jq ${PREFIX}/lib/jq/i3jq/
	install -m644 contrib/layout/*.jq ${PREFIX}/lib/jq/i3jq/layout/

.PHONY: uninstall
uninstall:
	rm -rf ${PREFIX}/bin/i3jq

.PRECIOUS: builtin.go
builtin.go: builtin.generator.go ${BUILTIN_JQ}
	$(GO) generate

%: %.go $(filter-out builtin.generator.go,$(wildcard *.go)) builtin.go
	$(GO) build -ldflags=$(LDFLAGS) -o $@ $^
