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
	mkdir -p ${PREFIX}/share/i3jq/layout/
	install -m644 contrib/*.jq ${PREFIX}/share/i3jq/
	install -m644 contrib/layout/*.jq ${PREFIX}/share/i3jq/layout/

.PHONY: uninstall
uninstall:
	rm -rf ${PREFIX}/bin/i3jq
	rm -rf ${PREFIX}/share/i3jq

.PRECIOUS: builtin.go
builtin.go: _tools/gen_builtin.go ${BUILTIN_JQ}
	$(GO) generate

%: %.go $(wildcard *.go) builtin.go
	$(GO) build -ldflags=$(LDFLAGS) -o $@ $^
