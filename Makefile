.PHONY: release

VERSION := $(shell git describe --tags)
LDFLAGS := '-s -w -X main.version=$(VERSION)'

rget: main.go Gopkg.toml Gopkg.lock
	dep check || dep ensure
	go build -ldflags $(LDFLAGS) -o $@

release:
	GOOS=linux GOARCH=amd64 go build -ldflags $(LDFLAGS) -o rget-linux-amd64
	gzip rget-linux-amd64
