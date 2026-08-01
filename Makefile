.PHONY: all fmt lint test race build check

all: check

fmt:
	@test -z "$$(gofmt -l .)" || (gofmt -d . && exit 1)

lint:
	go vet ./...

test:
	go test ./...

race:
	go test -race ./...

build:
	go build -trimpath ./...

check: fmt lint race build
