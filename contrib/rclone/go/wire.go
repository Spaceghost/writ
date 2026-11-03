package writ

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/rclone/rclone/fs/fserrors"
)

const (
	maxFile = 64 << 10
	maxPath = 512
	// 256 files plus 256 directories at the maximum path length fit below
	// 600 KiB. The response bound must admit every complete service listing.
	maxResponse = 1 << 20
	rpcTimeout  = 5 * time.Second
)

type client struct{ address, token string }
type record struct {
	kind, path, text, hash       string
	id, version, secrecy, origin uint32
	size                         uint32
}
type serviceError string

func (e serviceError) Error() string { return string(e) }

const notFound = serviceError("NOT_FOUND")

func stop(err error) error {
	return fserrors.NoLowLevelRetryError(fserrors.NoRetryError(err))
}

func invalidResponse() error { return stop(errors.New("writ: invalid service response")) }

func newClient(address, token string) (client, error) {
	ap, err := netip.ParseAddrPort(address)
	if err != nil || !ap.Addr().IsLoopback() || ap.Port() == 0 || ap.Addr().Zone() != "" {
		return client{}, stop(errors.New("writ: address must be a numeric loopback address and port"))
	}
	if len(token) == 0 || len(token) > 128 {
		return client{}, stop(errors.New("writ: supply a token of at most 128 ASCII characters"))
	}
	for _, b := range []byte(token) {
		if b < 33 || b > 126 {
			return client{}, stop(errors.New("writ: token must contain printable ASCII without whitespace"))
		}
	}
	return client{ap.String(), token}, nil
}

// Paths are logical names, never local filesystem paths. Reject traversal instead
// of cleaning it into a different request; the Bend service chooses namespaces.
func validPath(p string) bool {
	if len(p) > maxPath || !utf8.ValidString(p) {
		return false
	}
	if p == "" {
		return true
	}
	for _, c := range p {
		if c < 32 || c == 127 || c == '\\' {
			return false
		}
	}
	for _, part := range strings.Split(p, "/") {
		if part == "" || part == "." || part == ".." {
			return false
		}
	}
	return true
}

func decode(s string) (string, error) {
	b, err := hex.DecodeString(s)
	if err != nil || !utf8.Valid(b) || hex.EncodeToString(b) != s {
		return "", invalidResponse()
	}
	return string(b), nil
}

func parseResponse(b []byte) ([]record, error) {
	if len(b) == 0 || len(b) > maxResponse || b[len(b)-1] != '\n' {
		return nil, invalidResponse()
	}
	lines := strings.Split(string(b[:len(b)-1]), "\n")
	if strings.HasPrefix(lines[0], "ERR\t") && len(lines) == 1 {
		code := strings.TrimPrefix(lines[0], "ERR\t")
		switch code {
		case "DENIED", "NOT_FOUND", "IS_DIR", "NOT_DIR", "CONFLICT", "LIMIT", "INVALID", "UNSUPPORTED":
			return nil, stop(serviceError(code))
		}
	}
	// EOF alone cannot distinguish a complete LIST from a whole-row prefix
	// cut short by a failed send. The service emits END only after every row.
	if lines[0] != "OK" || len(lines) < 2 || lines[len(lines)-1] != "END" {
		return nil, invalidResponse()
	}
	lines = lines[1 : len(lines)-1]
	out := make([]record, 0, len(lines))
	for _, line := range lines {
		fields := strings.Split(line, "\t")
		r := record{kind: fields[0]}
		switch {
		case r.kind == "TEXT" && len(fields) == 2:
			var err error
			r.text, err = decode(fields[1])
			if err != nil {
				return nil, err
			}
		case (r.kind == "DIR" && len(fields) == 2) || (r.kind == "FILE" && len(fields) == 8):
			var err error
			r.path, err = decode(fields[1])
			if err != nil || !validPath(r.path) || (r.kind == "FILE" && r.path == "") {
				return nil, invalidResponse()
			}
			if r.kind == "FILE" {
				for i, target := range []*uint32{&r.id, &r.version, &r.size, &r.secrecy, &r.origin} {
					n, err := strconv.ParseUint(fields[i+2], 10, 32)
					if err != nil || strconv.FormatUint(n, 10) != fields[i+2] {
						return nil, invalidResponse()
					}
					*target = uint32(n)
				}
				if r.size > maxFile {
					return nil, invalidResponse()
				}
				r.hash = fields[7]
				digest, err := hex.DecodeString(r.hash)
				if err != nil || len(digest) != 32 || hex.EncodeToString(digest) != r.hash {
					return nil, invalidResponse()
				}
			}
		default:
			return nil, invalidResponse()
		}
		out = append(out, r)
	}
	return out, nil
}

// One bounded connection per request; no transport or policy retries. In
// particular a lost write response must retain its receipt key in the error.
func (c client) call(ctx context.Context, op, src, dst string, version, expected uint32, body []byte) (out []record, err error) {
	idBytes := make([]byte, 16)
	if _, err = rand.Read(idBytes); err != nil {
		return nil, stop(errors.New("writ: cannot generate request ID"))
	}
	id := hex.EncodeToString(idBytes)
	defer func() {
		if err != nil {
			err = stop(fmt.Errorf("writ %s request %s: %w", op, id, err))
		}
	}()
	if !validPath(src) || !validPath(dst) || len(body) > maxFile {
		return nil, errors.New("request exceeds path or body bounds")
	}
	fields := []string{"WRIT1", c.token, op, id, hex.EncodeToString([]byte(src)), hex.EncodeToString([]byte(dst)), strconv.FormatUint(uint64(version), 10), strconv.FormatUint(uint64(expected), 10), hex.EncodeToString(body)}
	ctx, cancel := context.WithTimeout(ctx, rpcTimeout)
	defer cancel()
	conn, err := (&net.Dialer{}).DialContext(ctx, "tcp", c.address)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	deadline, _ := ctx.Deadline()
	if err = conn.SetDeadline(deadline); err != nil {
		return nil, err
	}
	unwatch := context.AfterFunc(ctx, func() { _ = conn.Close() })
	defer unwatch()
	line := strings.Join(fields, "\t") + "\n"
	n, err := io.WriteString(conn, line)
	if err != nil {
		return nil, err
	}
	if n != len(line) {
		return nil, io.ErrShortWrite
	}
	b, err := io.ReadAll(io.LimitReader(conn, maxResponse+1))
	if err != nil {
		return nil, err
	}
	out, err = parseResponse(b)
	if err == nil && (op == "PUT" || op == "COPY") {
		p := src
		if op == "COPY" {
			p = dst
		}
		if len(out) != 1 || out[0].kind != "FILE" || out[0].path != p || (op == "PUT" && out[0].size != uint32(len(body))) {
			return nil, invalidResponse()
		}
	}
	return out, err
}
