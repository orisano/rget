# rget
rget is parallel downloader for GitHub release.

## Installation
```bash
go get github.com/orisano/rget
```
or
```bash
wget -O - https://github.com/orisano/rget/releases/download/0.1.3/rget-linux-amd64.gz | gzip -d -c > /usr/local/bin/rget && chmod +x /usr/local/bin/rget
```

## How to use
```
$ rget
Usage of rget:
  -o string
    	output file path (required)
  -u string
    	url (required)
  -b int
    	block size (MB)
  -P int
    	maxprocs (default 4)
  -x	add executable flag
  -v	show verbose
  -V	show version
```

## Author
Nao YONASHIRO (@orisano)

## License
MIT
