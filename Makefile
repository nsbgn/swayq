PREFIX?=/usr/local
GO?=$(word 1,$(wildcard /usr/lib/go-1.21/bin/go) $(shell which go))
REVISION=$(shell git rev-parse --short HEAD)
LDFLAGS="-s -w -X 'main.Version=$(REVISION)'"

BUILTIN_JQ = $(wildcard builtin/*.jq)
BIN="swayq"

.PHONY: all
all: build

.PHONY: build
build: swayq

.PHONY: clean
clean:
	rm -rf ${BIN} builtin.go
	go clean

.PHONY: install
install: swayq
	mkdir -p ${PREFIX}/bin/
	install -m755 ${BIN} ${PREFIX}/bin/
	ln -sf ${PREFIX}/bin/${BIN} ${PREFIX}/bin/i3q

.PHONY: uninstall
uninstall:
	rm -rf ${PREFIX}/bin/swayq ${PREFIX}/bin/i3q

.PRECIOUS: builtin.go
builtin.go: builtin.generator.go ${BUILTIN_JQ}
	$(GO) generate

%: %.go $(filter-out builtin.generator.go,$(wildcard *.go)) builtin.go
	$(GO) build -ldflags=$(LDFLAGS) -o $@ $^
