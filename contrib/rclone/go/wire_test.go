package writ

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"net"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/fserrors"
)

func testHex(s string) string { return hex.EncodeToString([]byte(s)) }

const testDigest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

func testServer(t *testing.T, reply string) (client, <-chan string) {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = l.Close() })
	requests := make(chan string, 1)
	go func() {
		conn, err := l.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
		line, _ := bufio.NewReader(conn).ReadString('\n')
		requests <- line
		if reply == "" { // A stalled peer: only cancellation or the deadline closes it.
			_, _ = io.Copy(io.Discard, conn)
			return
		}
		_, _ = io.WriteString(conn, reply)
	}()
	c, err := newClient(l.Addr().String(), strings.Repeat("a", 64))
	if err != nil {
		t.Fatal(err)
	}
	return c, requests
}

func TestDecodeBoundedCanonicalResponse(t *testing.T) {
	file := "FILE\t" + testHex("private/δ.txt") + "\t1\t2\t3\t4\t5\t" + testDigest + "\n"
	r, err := parseResponse([]byte("OK\n" + file + "DIR\t" + testHex("private/sub") + "\nTEXT\t6869\nEND\n"))
	if err != nil || len(r) != 3 || r[0].path != "private/δ.txt" || r[0].version != 2 || r[0].origin != 5 || r[2].text != "hi" {
		t.Fatalf("valid response: %#v, %v", r, err)
	}
	for _, bad := range []string{
		"", "OK", "OK\r\nEND\n", "OK\n\nEND\n", "FUTURE\n", "ERR\tNEW_CODE\n", "ERR\tDENIED\nOK\n",
		"OK\nTEXT\tff\nEND\n", "OK\nTEXT\t4F\nEND\n", "OK\nUNKNOWN\t00\nEND\n",
		"OK\n" + strings.Replace(file, "\t1\t2", "\t1\t02", 1) + "END\n",
		"OK\n" + strings.Replace(file, "\t1\t2", "\t1\t4294967296", 1) + "END\n",
		"OK\n" + strings.Replace(file, "\t2\t3", "\t2\t65537", 1) + "END\n",
		"OK\n" + strings.Replace(file, testDigest, "00", 1) + "END\n",
		"OK\n" + strings.Replace(file, testDigest, strings.ToUpper(testDigest), 1) + "END\n",
		"OK\nDIR\t" + testHex("private/../public") + "\nEND\n",
		"OK\nDIR\t" + testHex(strings.Repeat("x", maxPath+1)) + "\nEND\n",
		"OK\nTEXT\t" + strings.Repeat("61", maxResponse) + "\nEND\n",
		"OK\nEND\nEND\n", "OK\nEND\nextra\n",
	} {
		if _, err := parseResponse([]byte(bad)); err == nil {
			t.Fatalf("accepted malformed response of %d bytes", len(bad))
		}
	}
}

func TestTruncatedListingCannotBecomeSuccess(t *testing.T) {
	file := "FILE\t" + testHex("private/file") + "\t1\t1\t0\t1\t1\t" + testDigest + "\n"
	for _, prefix := range []string{"OK\n", "OK\n" + file, "OK\n" + file + "END"} {
		c, _ := testServer(t, prefix)
		if _, err := c.call(context.Background(), "LIST", "private", "", 0, 0, nil); err == nil {
			t.Fatal("connection close turned a truncated response into a complete listing")
		}
	}
	if r, err := parseResponse([]byte("OK\nEND\n")); err != nil || len(r) != 0 {
		t.Fatalf("explicitly complete empty listing failed: %v", err)
	}
}

func TestLoopbackAndTokenFraming(t *testing.T) {
	for _, address := range []string{"localhost:8787", "192.0.2.1:8787", "0.0.0.0:8787", "127.0.0.1:0", "127.0.0.1", "[::]:8787"} {
		if _, err := newClient(address, "token"); err == nil {
			t.Fatalf("accepted address %q", address)
		}
	}
	for _, address := range []string{"127.0.0.1:8787", "[::1]:8787"} {
		if _, err := newClient(address, "token"); err != nil {
			t.Fatal(err)
		}
	}
	for _, token := range []string{"", "has\ttab", "has\nnewline", "has space", strings.Repeat("x", 129)} {
		if _, err := newClient("127.0.0.1:8787", token); err == nil {
			t.Fatal("accepted a token that cannot fit one bounded ASCII field")
		}
	}
}

func TestNineFieldEnvelopeAndDenial(t *testing.T) {
	c, requests := testServer(t, "ERR\tDENIED\n")
	_, err := c.call(context.Background(), "COPY", "private/δ.txt", "public/out", 7, 11, nil)
	if err == nil || !errors.Is(err, serviceError("DENIED")) || errors.Is(err, fs.ErrorCantCopy) || !fserrors.IsNoRetryError(err) || !fserrors.IsNoLowLevelRetryError(err) {
		t.Fatalf("denial lost its terminal meaning: %v", err)
	}
	fields := strings.Split(strings.TrimSuffix(<-requests, "\n"), "\t")
	if len(fields) != 9 || fields[0] != "WRIT1" || fields[1] != c.token || fields[2] != "COPY" || fields[4] != testHex("private/δ.txt") || fields[5] != testHex("public/out") || fields[6] != "7" || fields[7] != "11" || fields[8] != "" {
		t.Fatal("request differs from the nine-field contract")
	}
	id, decodeErr := hex.DecodeString(fields[3])
	if decodeErr != nil || len(id) != 16 || hex.EncodeToString(id) != fields[3] || !strings.Contains(err.Error(), "request "+fields[3]) || strings.Contains(err.Error(), c.token) {
		t.Fatal("error must contain the request ID, and never the token")
	}
}

func TestBinaryPutAndMalformedWriteReceipt(t *testing.T) {
	body := []byte{0, '\t', '\n', 255}
	digest := sha256.Sum256(body)
	c, requests := testServer(t, "OK\nFILE\t"+testHex("private/file")+"\t1\t2\t4\t1\t1\t"+hex.EncodeToString(digest[:])+"\nEND\n")
	r, err := c.call(context.Background(), "PUT", "private/file", "", 0, 1, body)
	if err != nil || len(r) != 1 || r[0].size != 4 {
		t.Fatalf("binary upload: %v", err)
	}
	fields := strings.Split(strings.TrimSuffix(<-requests, "\n"), "\t")
	if len(fields) != 9 || fields[8] != "00090aff" {
		t.Fatal("binary bytes escaped their hex field")
	}
	c, requests = testServer(t, "OK\nEND\n")
	_, err = c.call(context.Background(), "PUT", "private/file", "", 0, 0, body)
	fields = strings.Split(strings.TrimSuffix(<-requests, "\n"), "\t")
	if err == nil || !strings.Contains(err.Error(), fields[3]) {
		t.Fatal("malformed write response must fail with its receipt lookup ID")
	}
}

func TestOpenNeverReturnsAReader(t *testing.T) {
	c, _ := testServer(t, "OK\nTEXT\t736563726574\nEND\n")
	o := &Object{f: &Fs{client: c}, record: record{path: "private/file", version: 1}}
	reader, err := o.Open(context.Background())
	if reader != nil || err == nil || !fserrors.IsNoRetryError(err) {
		t.Fatal("unexpected OPEN success released a reader")
	}
}

func TestTransportResponseLimit(t *testing.T) {
	c, _ := testServer(t, "OK\nTEXT\t"+strings.Repeat("61", maxResponse)+"\nEND\n")
	if _, err := c.call(context.Background(), "STATUS", "", "", 0, 0, nil); err == nil {
		t.Fatal("oversized response was accepted")
	}
}

func TestMaximumMetadataListingFitsResponseLimit(t *testing.T) {
	var b strings.Builder
	b.WriteString("OK\n")
	for i := range 256 {
		for _, kind := range []string{"FILE", "DIR"} {
			p := "private/" + strings.ToLower(kind) + "-" + strconv.Itoa(i) + "-"
			p += strings.Repeat("x", maxPath-len(p))
			b.WriteString(kind + "\t" + testHex(p))
			if kind == "FILE" {
				b.WriteString("\t256\t256\t65536\t1\t256\t" + testDigest)
			}
			b.WriteByte('\n')
		}
	}
	b.WriteString("END\n")
	if b.Len() <= 256<<10 || b.Len() > maxResponse {
		t.Fatalf("maximum metadata population needs %d bytes", b.Len())
	}
	r, err := parseResponse([]byte(b.String()))
	if err != nil || len(r) != 512 {
		t.Fatalf("complete bounded listing was rejected: %v", err)
	}
}

func TestTransportHonorsContextDeadline(t *testing.T) {
	c, _ := testServer(t, "")
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	start := time.Now()
	_, err := c.call(ctx, "STATUS", "", "", 0, 0, nil)
	if err == nil || !fserrors.IsNoLowLevelRetryError(err) || time.Since(start) > time.Second {
		t.Fatalf("stalled peer did not stop at the request deadline: %v", err)
	}
}
