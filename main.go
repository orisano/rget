package main

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"github.com/orisano/usage"
)

var version string
var buildVersion = "HEAD (" + time.Now().Format(time.RFC3339) + ")"

var verbose = flag.Bool("v", false, "show verbose")

type writeReq struct {
	offset int
	buf    *bytes.Buffer
}

func main() {
	flag.Usage = usage.Ordered("o", "u", "b", "P", "x", "v", "V")

	outputPath := flag.String("o", "", "output file path (required)")
	urlStr := flag.String("u", "", "url (required)")
	procs := flag.Int("P", 4, "maxprocs")
	blockSizeMB := flag.Int("b", 0, "block size (MB)")
	executable := flag.Bool("x", false, "add executable flag")
	showVersion := flag.Bool("V", false, "show version")
	flag.Parse()

	log.SetFlags(0)
	log.SetPrefix("rget: ")

	if *showVersion {
		if len(version) == 0 {
			fmt.Println(buildVersion)
		} else {
			fmt.Println(version)
		}
		return
	}

	if len(*outputPath) == 0 || len(*urlStr) == 0 {
		flag.Usage()
		os.Exit(2)
	}

	if !isValidURL(*urlStr) {
		log.Fatalf("invalid url: %q", *urlStr)
	}

	mode := 0666
	if *executable {
		mode |= 0111
	}
	f, err := os.OpenFile(*outputPath, os.O_RDWR|os.O_CREATE|os.O_TRUNC, os.FileMode(mode))
	if err != nil {
		log.Fatalf("failed to create file: %v", err)
	}
	defer f.Close()

	contentLength, err := getContentLength(*urlStr)
	if err != nil {
		log.Fatalf("failed to get content length: %v", err)
	}
	verbosefln("Content-Length: %v", contentLength)

	blockSize := *blockSizeMB * 1024 * 1024
	if blockSize == 0 {
		blockSize = (contentLength + *procs - 1) / *procs
	}
	verbosefln("BlockSize: %v", blockSize)

	blocks := (contentLength + blockSize - 1) / blockSize
	blockCh := make(chan int, blocks)
	for i := 0; i < blocks; i++ {
		blockCh <- i
	}
	close(blockCh)

	writeReqCh := make(chan writeReq, *procs*2)

	pool := sync.Pool{
		New: func() interface{} {
			return bytes.NewBuffer(make([]byte, blockSize))
		},
	}
	for i := 0; i < *procs; i++ {
		go func() {
			for b := range blockCh {
				offset := b * blockSize
				rangeVal := fmt.Sprint("bytes=", offset, "-", offset+blockSize-1)

				for {
					req, _ := http.NewRequest(http.MethodGet, *urlStr, nil)
					req.Header.Set("Range", rangeVal)
					resp, err := http.DefaultClient.Do(req)
					if err != nil {
						log.Fatalf("failed to request: %v", err)
					}
					verbosefln("downloading... %v", rangeVal)
					buf := pool.Get().(*bytes.Buffer)
					buf.Reset()
					_, err = io.Copy(buf, resp.Body)
					if isTemporary(err) {
						verbosefln("got temporary error, will attempt to retry: %v", err.Error())
						continue
					}
					if err != nil && err != io.EOF {
						log.Fatalf("failed to read body: %v", err)
					}
					resp.Body.Close()

					writeReqCh <- writeReq{
						offset: offset,
						buf:    buf,
					}
					break
				}
			}
		}()
	}

	for i := 0; i < blocks; i++ {
		wr := <-writeReqCh
		if _, err := f.Seek(int64(wr.offset), 0); err != nil {
			log.Fatalf("failed to seek file: %v", err)
		}
		verbosefln("writing... (%d/%d): %v", i+1, blocks, wr.offset)
		if _, err := io.Copy(f, wr.buf); err != nil {
			log.Fatalf("failed to write file: %v", err)
		}
		pool.Put(wr.buf)
	}
}

func verbosefln(format string, a ...interface{}) {
	if *verbose {
		fmt.Fprintf(os.Stderr, format, a...)
		fmt.Fprintln(os.Stderr)
	}
}

func isValidURL(urlStr string) bool {
	_, err := url.ParseRequestURI(urlStr)
	return err == nil
}

func getContentLength(urlStr string) (int, error) {
	resp, err := http.Get(urlStr)
	if err != nil {
		return 0, err
	}
	resp.Body.Close()
	return int(resp.ContentLength), nil
}

func isTemporary(err error) bool {
	type temporary interface {
		Temporary() bool
	}
	te, ok := err.(temporary)
	return ok && te.Temporary()
}
