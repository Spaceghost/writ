// Package writ is rclone's transport adapter for the local Bend reference service.
// It carries requests and version preconditions; policy stays in Bend.
package writ

import (
	"context"
	"encoding/hex"
	"errors"
	"io"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/config/configmap"
	"github.com/rclone/rclone/fs/hash"
)

func init() {
	fs.Register(&fs.RegInfo{
		Name: "writ", Description: "Writ local Bend reference service", NewFs: NewFs,
		Options: []fs.Option{
			{Name: "address", Default: "127.0.0.1:8787", Help: "Numeric loopback TCP address of the reference service."},
			{Name: "token", Sensitive: true, Help: "Local service token; WRIT_RCLONE_TOKEN takes precedence."},
		},
		CommandHelp: []fs.CommandHelp{
			{Name: "policy", Short: "Inspect service-owned policy for a relative path.", Long: "rclone backend policy writ: private/file"},
			{Name: "receipt", Short: "Look up a request ID in this service instance.", Long: "rclone backend receipt writ: REQUEST_ID"},
			{Name: "status", Short: "Inspect the in-memory reference service."},
		},
	})
}

// Fs is a view into a logical directory of the reference service.
type Fs struct {
	name, root string
	client     client
	features   *fs.Features
}

// Object holds service-provided metadata and a version precondition.
type Object struct {
	f      *Fs
	remote string
	record record
}

// NewFs connects to the bounded local service. Missing roots may be created;
// file roots return their parent filesystem with rclone's ErrorIsFile sentinel.
func NewFs(ctx context.Context, name, root string, m configmap.Mapper) (fs.Fs, error) {
	root = strings.Trim(root, "/")
	if !validPath(root) {
		return nil, stop(errors.New("writ: invalid root path"))
	}
	address, _ := m.Get("address")
	if address == "" {
		address = "127.0.0.1:8787"
	}
	token := os.Getenv("WRIT_RCLONE_TOKEN")
	if token == "" {
		token, _ = m.Get("token")
	}
	c, err := newClient(address, token)
	if err != nil {
		return nil, err
	}
	f := &Fs{name: name, root: root, client: c}
	f.features = (&fs.Features{}).Fill(ctx, f)
	r, err := f.stat(ctx, root)
	if errors.Is(err, notFound) {
		return f, nil
	}
	if err != nil {
		return nil, err
	}
	if r.kind == "FILE" {
		f.root = parent(root)
		return f, fs.ErrorIsFile
	}
	return f, nil
}

func parent(p string) string {
	if d := path.Dir(p); d != "." {
		return d
	}
	return ""
}

func (f *Fs) full(remote string) (string, error) {
	if !validPath(remote) {
		return "", stop(errors.New("writ: invalid relative path"))
	}
	p := remote
	if f.root != "" {
		p = f.root
		if remote != "" {
			p += "/" + remote
		}
	}
	if !validPath(p) {
		return "", stop(errors.New("writ: path exceeds limit"))
	}
	return p, nil
}

func (f *Fs) relative(p string) (string, error) {
	if f.root == "" {
		return p, nil
	}
	if !strings.HasPrefix(p, f.root+"/") {
		return "", invalidResponse()
	}
	return strings.TrimPrefix(p, f.root+"/"), nil
}

func (f *Fs) stat(ctx context.Context, p string) (record, error) {
	r, err := f.client.call(ctx, "STAT", p, "", 0, 0, nil)
	if err != nil {
		return record{}, err
	}
	if len(r) != 1 || r[0].path != p || (r[0].kind != "FILE" && r[0].kind != "DIR") {
		return record{}, invalidResponse()
	}
	return r[0], nil
}

func (f *Fs) object(r []record, p string) (fs.Object, error) {
	if len(r) != 1 || r[0].kind != "FILE" || r[0].path != p {
		return nil, invalidResponse()
	}
	remote, err := f.relative(p)
	if err != nil {
		return nil, err
	}
	return &Object{f, remote, r[0]}, nil
}

func (f *Fs) Name() string                          { return f.name }
func (f *Fs) Root() string                          { return f.root }
func (f *Fs) String() string                        { return "Writ reference service: " + f.root }
func (f *Fs) Precision() time.Duration              { return fs.ModTimeNotSupported }
func (f *Fs) Hashes() hash.Set                      { return hash.NewHashSet(hash.SHA256) }
func (f *Fs) Features() *fs.Features                { return f.features }
func (o *Object) Fs() fs.Info                       { return o.f }
func (o *Object) String() string                    { return o.remote }
func (o *Object) Remote() string                    { return o.remote }
func (o *Object) ModTime(context.Context) time.Time { return time.Time{} }
func (o *Object) Size() int64                       { return int64(o.record.size) }
func (o *Object) Storable() bool                    { return true }
func (o *Object) ID() string                        { return strconv.FormatUint(uint64(o.record.id), 10) }
func (o *Object) Hash(_ context.Context, kind hash.Type) (string, error) {
	if kind == hash.SHA256 {
		return o.record.hash, nil
	}
	return "", hash.ErrUnsupported
}

// List exposes only the service's complete immediate-child response.
func (f *Fs) List(ctx context.Context, dir string) (fs.DirEntries, error) {
	p, err := f.full(dir)
	if err != nil {
		return nil, err
	}
	r, err := f.client.call(ctx, "LIST", p, "", 0, 0, nil)
	if errors.Is(err, notFound) {
		return nil, fs.ErrorDirNotFound
	}
	if err != nil {
		return nil, err
	}
	entries := make(fs.DirEntries, 0, len(r))
	seen := make(map[string]bool, len(r))
	for _, entry := range r {
		if entry.path == p || parent(entry.path) != p || seen[entry.path] {
			return nil, invalidResponse()
		}
		seen[entry.path] = true
		remote, err := f.relative(entry.path)
		if err != nil {
			return nil, err
		}
		switch entry.kind {
		case "FILE":
			entries = append(entries, &Object{f, remote, entry})
		case "DIR":
			entries = append(entries, fs.NewDir(remote, time.Time{}))
		default:
			return nil, invalidResponse()
		}
	}
	return entries, nil
}

func (f *Fs) NewObject(ctx context.Context, remote string) (fs.Object, error) {
	p, err := f.full(remote)
	if err != nil {
		return nil, err
	}
	r, err := f.stat(ctx, p)
	if errors.Is(err, notFound) {
		return nil, fs.ErrorObjectNotFound
	}
	if err != nil {
		return nil, err
	}
	if r.kind == "DIR" {
		return nil, fs.ErrorIsDir
	}
	return f.object([]record{r}, p)
}

func (f *Fs) destinationVersion(ctx context.Context, p string) (uint32, error) {
	r, err := f.stat(ctx, p)
	if errors.Is(err, notFound) {
		return 0, nil
	}
	if err == nil && r.kind == "DIR" {
		err = fs.ErrorIsDir
	}
	return r.version, err
}

func (f *Fs) put(ctx context.Context, p string, expected uint32, in io.Reader, size int64) (fs.Object, error) {
	if size > maxFile {
		return nil, stop(errors.New("writ: file exceeds 64 KiB reference limit"))
	}
	b, err := io.ReadAll(io.LimitReader(in, maxFile+1))
	if err != nil {
		return nil, stop(err)
	}
	if len(b) > maxFile || (size >= 0 && int64(len(b)) != size) {
		return nil, stop(errors.New("writ: file exceeds limit or declared size differs"))
	}
	r, err := f.client.call(ctx, "PUT", p, "", 0, expected, b)
	if err != nil {
		return nil, err
	}
	return f.object(r, p)
}

func (f *Fs) Put(ctx context.Context, in io.Reader, src fs.ObjectInfo, _ ...fs.OpenOption) (fs.Object, error) {
	p, err := f.full(src.Remote())
	if err != nil {
		return nil, err
	}
	v, err := f.destinationVersion(ctx, p)
	if err != nil {
		return nil, err
	}
	return f.put(ctx, p, v, in, src.Size())
}

func (o *Object) Update(ctx context.Context, in io.Reader, src fs.ObjectInfo, _ ...fs.OpenOption) error {
	updated, err := o.f.put(ctx, o.record.path, o.record.version, in, src.Size())
	if err == nil {
		*o = *updated.(*Object)
	}
	return err
}

// Copy is deliberately a complete service request. A denial must never become
// ErrorCantCopy, which would ask rclone to fall back to client-side plaintext.
func (f *Fs) Copy(ctx context.Context, src fs.Object, remote string) (fs.Object, error) {
	o, ok := src.(*Object)
	if !ok || o.f.name != f.name || o.f.client != f.client {
		return nil, stop(errors.New("writ: copy requires the same configured service"))
	}
	p, err := f.full(remote)
	if err != nil {
		return nil, err
	}
	v, err := f.destinationVersion(ctx, p)
	if err != nil {
		return nil, err
	}
	r, err := f.client.call(ctx, "COPY", o.record.path, p, o.record.version, v, nil)
	if err != nil {
		return nil, err
	}
	return f.object(r, p)
}

func (f *Fs) Mkdir(ctx context.Context, dir string) error {
	p, err := f.full(dir)
	if err != nil {
		return err
	}
	r, err := f.client.call(ctx, "MKDIR", p, "", 0, 0, nil)
	if err == nil && (len(r) != 1 || r[0].kind != "DIR" || r[0].path != p) {
		err = invalidResponse()
	}
	return err
}

func unsupported() error                                      { return stop(errors.New("writ: unsupported by the reference service")) }
func (f *Fs) Rmdir(context.Context, string) error             { return unsupported() }
func (o *Object) Remove(context.Context) error                { return unsupported() }
func (o *Object) SetModTime(context.Context, time.Time) error { return unsupported() }

func (o *Object) Open(ctx context.Context, _ ...fs.OpenOption) (io.ReadCloser, error) {
	_, err := o.f.client.call(ctx, "OPEN", o.record.path, "", o.record.version, 0, nil)
	if err == nil {
		err = stop(errors.New("writ: successful OPEN is invalid; this adapter cannot release plaintext"))
	}
	return nil, err
}

// Command forwards bounded inspection requests. Returned text is descriptive;
// callers cannot supply policy, grants, or a release decision through this API.
func (f *Fs) Command(ctx context.Context, name string, arg []string, opt map[string]string) (any, error) {
	if len(opt) != 0 {
		return nil, unsupported()
	}
	p := f.root
	switch name {
	case "policy":
		if len(arg) > 1 {
			return nil, unsupported()
		}
		if len(arg) == 1 {
			var err error
			p, err = f.full(arg[0])
			if err != nil {
				return nil, err
			}
		}
	case "receipt":
		if len(arg) != 1 || len(arg[0]) != 32 {
			return nil, stop(errors.New("writ: receipt needs one 32-character request ID"))
		}
		b, err := hex.DecodeString(arg[0])
		if err != nil || hex.EncodeToString(b) != arg[0] {
			return nil, stop(errors.New("writ: invalid request ID"))
		}
		p = arg[0]
	case "status":
		if len(arg) != 0 {
			return nil, unsupported()
		}
	default:
		return nil, fs.ErrorCommandNotFound
	}
	r, err := f.client.call(ctx, strings.ToUpper(name), p, "", 0, 0, nil)
	if err != nil {
		return nil, err
	}
	text := make([]string, 0, len(r))
	for _, entry := range r {
		if entry.kind != "TEXT" {
			return nil, invalidResponse()
		}
		text = append(text, entry.text)
	}
	return text, nil
}

var (
	_ fs.Fs        = (*Fs)(nil)
	_ fs.Object    = (*Object)(nil)
	_ fs.Copier    = (*Fs)(nil)
	_ fs.Commander = (*Fs)(nil)
)
