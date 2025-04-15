PREFIX?=/usr/local
GO?=$(word 1,$(wildcard /usr/lib/go-1.21/bin/go) $(shell which go))
REVISION=$(shell git rev-parse --short HEAD)
LDFLAGS="-s -w -X 'main.Version=$(REVISION)'"

BUILTIN_JQ = $(wildcard builtin/*.jq)

.PHONY: all
all: build

.PHONY: build
build: i3q

.PHONY: clean
clean:
	rm -rf i3q builtin.go
	go clean

.PHONY: install
install: i3q
	mkdir -p ${PREFIX}/bin/
	install -m755 i3q ${PREFIX}/bin/
	ln -sf ${PREFIX}/bin/i3q ${PREFIX}/bin/swayq

.PHONY: uninstall
uninstall:
	rm -rf ${PREFIX}/bin/i3q ${PREFIX}/bin/swayq

.PRECIOUS: builtin.go
builtin.go: builtin.generator.go ${BUILTIN_JQ}
	$(GO) generate

%: %.go $(filter-out builtin.generator.go,$(wildcard *.go)) builtin.go
	$(GO) build -ldflags=$(LDFLAGS) -o $@ $^
