package main

import (
	"compress/zlib"
	"fmt"
	"io"
	"math/rand"
	"os"
)

const (
	chunkZero = iota
	chunkRepeat
	chunkRand
	CHUNK_BOUNDRAY
)

const perChunkMaxLength = 1024

func main() {
	input, inputWriter := io.Pipe()

	go func() {
		var zeros [perChunkMaxLength]byte
		var buf [perChunkMaxLength]byte
		r := rand.New(rand.NewSource(31))
		for {
			chunkTyp := r.Intn(CHUNK_BOUNDRAY)
			chunkLen := r.Intn(perChunkMaxLength + 1)
			if chunkLen == 0 {
				continue
			}
			switch chunkTyp {
			case chunkZero:
				inputWriter.Write(zeros[:chunkLen])
			case chunkRepeat:
				chunkSplitLen := max(r.Intn(chunkLen / 4 + 1), 1)
				r.Read(buf[:chunkSplitLen])
				for i := 0; i < (chunkLen + chunkSplitLen - 1) / chunkSplitLen; i++  {
					inputWriter.Write(buf[:chunkSplitLen])
				}
			case chunkRand:
				r.Read(buf[:chunkLen])
				inputWriter.Write(buf[:chunkLen])
			}
		}
	}()

	for i := range 3 {
		CreateZlib(fmt.Sprintf("./1b_%d.zlib", i), io.LimitReader(input, 1))
		CreateZlib(fmt.Sprintf("./1kb_%d.zlib", i), io.LimitReader(input, 1024))
		CreateZlib(fmt.Sprintf("./1mb_%d.zlib", i), io.LimitReader(input, 1024 * 1024))
		CreateZlib(fmt.Sprintf("./100mb_%d.zlib", i), io.LimitReader(input, 100 * 1024 * 1024))
	}
}

func CreateZlib(name string, src io.Reader) {
	fmt.Println("Creating", name)
	fd, err := os.Create(name)
	if err != nil {
		panic(err)
	}
	defer fd.Close()
	w, err := zlib.NewWriterLevel(fd, zlib.BestCompression)
	if err != nil {
		panic(err)
	}
	defer w.Close()
	if _, err := io.Copy(w, src); err != nil {
		panic(err)
	}
}
