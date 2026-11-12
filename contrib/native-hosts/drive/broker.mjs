// Native filesystem, S3 and process effects for the local owner's desktop.
// All catalog changes and reconciliation outcomes come from generated Bend.
import { mkdir, open, readFile, rename, lstat, readdir, unlink } from 'node:fs/promises';
import { constants } from 'node:fs';
import { join, dirname, resolve, sep } from 'node:path';
import { randomBytes } from 'node:crypto';
import { spawn } from 'node:child_process';
import { S3, sha256, validateConnection } from './s3.mjs';
import { DecisionError, requireChange, rows, load, streamDigest } from './policy.mjs';

const emptyHash = sha256('');
const fresh = () => randomBytes(20).toString('hex');
const missing = error => error.code === 'ENOENT';
export async function privateDirectory(path) {
  await mkdir(path, { recursive: true, mode: 0o700 });
  const info = await lstat(path);
  if (!info.isDirectory() || info.isSymbolicLink() ||
      (process.platform !== 'win32' && (info.uid !== process.getuid() || (info.mode & 0o077))))
    throw Error('Writ requires a private directory owned by this account.');
}
export async function atomic(path, bytes) {
  const temporary = path + '.' + fresh();
  const file = await open(temporary, 'wx', 0o600);
  try { await file.writeFile(bytes); await file.sync(); } finally { await file.close(); }
  await rename(temporary, path);
  if (process.platform !== 'win32') {
    const directory = await open(dirname(path), 'r');
    try { await directory.sync(); } finally { await directory.close(); }
  }
}
function powershell(script, input) {
  return new Promise((resolve, reject) => {
    const child = spawn('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    const output = []; let size = 0;
    const deadline = setTimeout(() => child.kill(), 30000);
    child.stdout.on('data', bytes => { size += bytes.length; if (size > 1048576) child.kill(); else output.push(bytes); });
    child.stderr.resume(); child.on('error', reject);
    child.on('exit', code => { clearTimeout(deadline); code === 0 ? resolve(Buffer.concat(output)) : reject(Error('Windows credential protection failed.')); });
    child.stdin.on('error', () => {}); child.stdin.end(input);
  });
}
async function protect(bytes, decrypt = false) {
  if (process.platform !== 'win32') return bytes;
  const script = 'Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); ' +
    '$r=[Security.Cryptography.ProtectedData]::' + (decrypt ? 'Unprotect' : 'Protect') +
    '($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::Write([Convert]::ToBase64String($r))';
  return Buffer.from((await powershell(script, bytes.toString('base64'))).toString().trim(), 'base64');
}
export async function openNative(path) {
  if (process.platform === 'win32') {
    await powershell('$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([Console]::In.ReadToEnd())); Start-Process -FilePath $p', Buffer.from(path).toString('base64'));
  } else {
    await new Promise((resolve, reject) => {
      const child = spawn('/usr/bin/xdg-open', [path], { detached: true, stdio: 'ignore' });
      child.on('error', reject); child.once('spawn', () => { child.unref(); resolve(); });
    });
  }
}
function binding(c) { return sha256(JSON.stringify([c.endpoint, c.region, c.bucket, c.prefix])); }
function payloadKey(s3, file) { return s3.key(`objects/${file.id}-${file.version}-${file.digest}`); }
function snapshot(file) { return file ? { $: 'Snapshot', kind: 1, version: file.version, size: file.size, digest: file.digest } :
  { $: 'Snapshot', kind: 0, version: 0, size: 0, digest: emptyHash }; }
export function safeMessage(error) {
  if (error instanceof DecisionError) return error.code;
  if (error.status) return `Storage returned ${error.status} (${error.code}).`;
  // Network/credential-provider exceptions can contain request options. Keep
  // those out of activity and responses, including endpoint-supplied messages.
  if (error.code) return ['ENOENT', 'EEXIST', 'EACCES', 'ENOSPC'].includes(error.code) ? error.code : 'Native operation failed; files retained.';
  return /^[A-Za-z0-9 .,;:'()/-]{1,180}$/.test(error.message || '') ? error.message : 'Operation did not complete; files retained.';
}

export class Broker {
  constructor(policy, sync, directory, folder) {
    this.policy = policy; this.sync = sync; this.directory = resolve(directory); this.folder = resolve(folder);
    this.state = policy.empty(); this.etag = ''; this.config = { connections: [] }; this.local = {};
    if (this.directory === this.folder || this.directory.startsWith(this.folder + sep) || this.folder.startsWith(this.directory + sep))
      throw Error('Keep the working folder and private app state separate.');
    this.activity = []; this.observations = {}; this.fetched = 0; this.sent = 0;
    this.paused = false; this.problem = ''; this.queue = Promise.resolve();
  }
  exclusive(work) { const next = this.queue.then(work); this.queue = next.catch(() => {}); return next; }
  view() { return rows(this.policy.dump(this.state)); }
  client(id) {
    const c = this.config.connections.find(c => c.id === id);
    const current = this.view().connections.find(c => c.id === id);
    if (!c || (current && current.binding !== binding(c))) throw new DecisionError('CONNECTION_IDENTITY_CHANGED');
    return new S3(c);
  }
  primary() { return this.client(1); }
  async initialize() {
    for (const p of [this.directory, join(this.directory, 'pending'), join(this.directory, 'Recovery'), this.folder]) await privateDirectory(p);
    for (const [name, field] of [['connections', 'config'], ['local.json', 'local'], ['activity.json', 'activity']]) {
      try {
        if ((await lstat(join(this.directory, name))).size > 1048576) throw Error('Local state limit reached.');
        let bytes = await readFile(join(this.directory, name));
        if (bytes.length > 1048576) throw Error('Local state limit reached.');
        if (name === 'connections') bytes = await protect(bytes, true);
        this[field] = JSON.parse(bytes);
      } catch (error) { if (!missing(error)) throw error; }
    }
    if (this.config.connections.length) {
      try { await this.refresh(); }
      catch (error) {
        this.problem = safeMessage(error);
        try { this.state = load(this.policy, await readFile(join(this.directory, 'catalog'), 'utf8')); } catch (e) { if (!missing(e)) throw e; }
      }
    }
    return this;
  }
  async event(kind, detail, file = null, destination = null) {
    this.activity.push({ time: new Date().toISOString(), kind, detail, path: file?.path || '', version: file?.version || 0, destination });
    this.activity = this.activity.slice(-256);
    await atomic(join(this.directory, 'activity.json'), JSON.stringify(this.activity));
  }
  async saveConfig() { await atomic(join(this.directory, 'connections'), await protect(Buffer.from(JSON.stringify(this.config)))); }
  async refresh() {
    const remote = await this.primary().catalog();
    if (!remote.bytes && this.view().files.length) throw Error('Established cloud catalog is missing; local files retained.');
    this.state = remote.bytes ? load(this.policy, remote.bytes.toString('utf8')) : this.policy.empty();
    this.etag = remote.etag; this.problem = '';
    for (const c of this.view().connections) {
      const configured = this.config.connections.find(local => local.id === c.id);
      if (configured && binding(configured) !== c.binding) throw new DecisionError('CONNECTION_IDENTITY_CHANGED');
    }
    await atomic(join(this.directory, 'catalog'), this.policy.dump(this.state));
  }
  async publish(state) {
    const text = this.policy.dump(state);
    // The S3 compare-and-swap is the linearization point of this exact Bend
    // state transition. No payload effect is invoked before its success.
    try {
      this.etag = await this.primary().replaceCatalog(Buffer.from(text), this.etag);
    } catch (error) {
      // A timeout is ambiguous. Reconcile only the exact proposed state; never
      // substitute a fresh version or an unconditional publication.
      const observed = await this.primary().catalog().catch(() => null);
      if (!observed?.bytes || observed.bytes.toString('utf8') !== text) throw error;
      this.etag = observed.etag;
    }
    this.state = state;
    await atomic(join(this.directory, 'catalog'), text);
  }
  async connect(input) {
    const c = validateConnection(input), first = !this.config.connections.length;
    const id = input.id || (first ? 1 : Math.max(...this.view().connections.map(c => c.id)) + 1);
    if (!Number.isInteger(id) || id < 1 || id > 16) throw Error('The workspace supports up to 16 storage connections.');
    const native = new S3(c); await native.probeConditions();
    const old = this.config;
    this.config = { connections: [...old.connections.filter(c => c.id !== id), { ...c, id }] };
    try {
      await this.refresh();
      const updated = requireChange(this.policy, this.policy.configure(this.state, id, input.name, binding(c), input.clearance, true));
      // Save credentials before the durable catalog can reference the binding.
      await this.saveConfig(); await this.publish(updated);
      await privateDirectory(join(this.folder, String(id)));
      await this.event('connected', 'Conditional storage writes verified.', null, id);
      return id;
    } catch (error) { this.config = old; await this.saveConfig(); throw error; }
  }
  async configure(id, clearance, enabled) {
    await this.refresh();
    const c = this.view().connections.find(c => c.id === id);
    if (!c) throw Error('Connection not found.');
    await this.publish(requireChange(this.policy, this.policy.configure(this.state, id, c.name, c.binding, clearance, enabled)));
    await this.event(enabled ? 'rules' : 'revoked', enabled ? 'Destination approvals updated.' : 'New managed reads and transfers disabled.', null, id);
  }
  async fetch(file) {
    if (!this.policy.readable(this.state, file.version)) throw new DecisionError('READ_NOT_ALLOWED');
    const s3 = this.client(file.connection);
    const result = await s3.get(payloadKey(s3, file), { maxBytes: file.size + 1 });
    this.fetched += result.bytes;
    if (result.bytes !== file.size || streamDigest(this.sync, result.body) !== file.digest) throw new DecisionError('CONTENT_MISMATCH');
    return result.body;
  }
  async transfer(request, bytes = null) {
    await this.refresh();
    const original = this.view().files.find(f => f.version === request.source);
    const metadata = bytes ? { size: bytes.length, digest: streamDigest(this.sync, bytes) } : original;
    if (!metadata) throw Error('Source version not found.');
    const change = this.policy.reserve(this.state, request.connection, request.path, metadata.size, metadata.digest,
      request.source || 0, request.expected || 0, request.extra || 0, request.kind);
    if (!this.policy.accepted(change)) {
      await this.event('denied', this.policy.status(change), original || { path: request.path }, request.connection);
      throw new DecisionError(this.policy.status(change));
    }
    const reserved = this.policy.next(change), pending = rows(this.policy.dump(reserved)).pending;
    if (!bytes) bytes = await this.fetch(original);
    // Private recovery is fsynced before publishing the pending authorization.
    // Failed conditions retain this original candidate; they do not leak bytes
    // to the destination and do not silently rebase onto another source version.
    const staged = join(this.directory, 'pending', `${pending.version}-${pending.digest}`);
    await atomic(staged, bytes);
    try {
      await this.publish(reserved);
      await this.event('pending', 'Transfer authorized; waiting for storage confirmation.', pending, pending.connection);
      await this.finishPending();
      return this.view().files.find(f => f.version === pending.version);
    } catch (error) {
      this.problem = safeMessage(error);
      await this.event('attention', this.problem + ' Candidate retained in recovery.', pending, pending.connection);
      throw error;
    }
  }
  async finishPending() {
    await this.refresh();
    const pending = this.view().pending;
    if (!pending) return;
    const staged = join(this.directory, 'pending', `${pending.version}-${pending.digest}`);
    let bytes;
    try { bytes = await readFile(staged); }
    catch (error) {
      // Another device can complete an uploaded pending effect without having
      // the sender's local file. It may not fabricate missing ingress bytes.
      if (!missing(error)) throw error;
    }
    const s3 = this.client(pending.connection), key = payloadKey(s3, pending);
    if (bytes) {
      if (bytes.length !== pending.size || streamDigest(this.sync, bytes) !== pending.digest) throw new DecisionError('CONTENT_MISMATCH');
      try { await s3.put(key, bytes, { 'if-none-match': '*' }); this.sent += bytes.length; }
      catch (error) { if (error.status !== 412) throw error; }
    }
    const confirmed = await s3.get(key, { maxBytes: pending.size + 1 }); this.fetched += confirmed.bytes;
    const digest = streamDigest(this.sync, confirmed.body);
    await this.publish(requireChange(this.policy, this.policy.confirm(this.state, pending.version, confirmed.bytes, digest)));
    await this.event('synced', 'Exact stored bytes verified. Origin restrictions retained.', pending, pending.connection);
    if (bytes) await unlink(staged).catch(() => {});
  }
  async localPath(file) {
    // Native pathname containment and link checks supplement Bend's canonical
    // cross-platform namespace rules. Never traverse user-created symlinks.
    const root = join(this.folder, String(file.connection)); await privateDirectory(root);
    let current = root;
    const parts = file.path.split('/');
    for (const part of parts.slice(0, -1)) {
      current = join(current, part); await mkdir(current, { mode: 0o700 }).catch(e => { if (e.code !== 'EEXIST') throw e; });
      const info = await lstat(current);
      if (!info.isDirectory() || info.isSymbolicLink()) throw Error('Linked working folders are not supported.');
    }
    const result = resolve(root, ...parts);
    if (!result.startsWith(root + sep)) throw Error('Invalid working path.');
    return result;
  }
  async snapshot(path) {
    const fd = await open(path, constants.O_RDONLY | (constants.O_NOFOLLOW || 0));
    try {
      const before = await fd.stat();
      if (!before.isFile() || before.nlink !== 1 || before.size > 67108864) throw Error('Use regular files up to 64 MiB.');
      const bytes = Buffer.alloc(before.size); let count = 0;
      while (count < bytes.length) {
        const part = await fd.read(bytes, count, bytes.length - count, count);
        if (!part.bytesRead) break; count += part.bytesRead;
      }
      const after = await fd.stat();
      if (count !== before.size || before.size !== after.size || before.mtimeMs !== after.mtimeMs || before.ctimeMs !== after.ctimeMs) throw Error('File is still changing; retry after saving.');
      return { bytes, digest: streamDigest(this.sync, bytes), size: bytes.length, ino: after.ino, dev: after.dev };
    } finally { await fd.close(); }
  }
  async keep(version, launch = false) {
    await this.refresh();
    const file = this.view().files.find(f => f.version === version);
    if (!file) throw Error('Version not found.');
    const path = await this.localPath(file), key = `${file.connection}/${file.path}`;
    const bytes = await this.fetch(file);
    try {
      const existing = await this.snapshot(path);
      if (existing.digest !== file.digest) throw Error('Local file differs. Its edits are retained; use History to open a separate copy.');
    } catch (error) {
      if (!missing(error)) throw error;
      const fd = await open(path, 'wx', 0o600);
      try { await fd.writeFile(bytes); await fd.sync(); } finally { await fd.close(); }
    }
    this.local[key] = { version: file.version, digest: file.digest };
    await atomic(join(this.directory, 'local.json'), JSON.stringify(this.local));
    await this.event('downloaded', 'Available in your working folder. Local edits will sync.', file);
    if (launch) await openNative(path);
    return path;
  }
  async historyCopy(version, launch = false) {
    await this.refresh(); const file = this.view().files.find(f => f.version === version);
    if (!file) throw Error('Version not found.');
    const path = join(this.directory, 'Recovery', `${file.version}-${fresh()}-${file.path.split('/').pop()}`);
    await atomic(path, await this.fetch(file));
    await this.event('history', 'Historical bytes opened as a separate local copy.', file);
    if (launch) await openNative(path);
    return path;
  }
  async listExisting(id, prefix, continuation = '') { return this.client(id).list(prefix, continuation); }
  async importExisting(request) {
    // Existing bucket objects enter as explicit owner-approved ingress. The
    // exact listed ETag prevents silently importing a later object version.
    const result = await this.client(request.connection).get(request.key, { headers: { 'if-match': request.etag }, maxBytes: 67108864 });
    this.fetched += result.bytes;
    return this.transfer({ ...request, source: 0, expected: 0, kind: 'save' }, result.body);
  }
  async scanDirectory(connection, directory, prefix = '', collected = []) {
    for (const item of await readdir(directory, { withFileTypes: true })) {
      if (collected.length >= 2048) throw Error('Working folder scan limit reached.');
      const relative = prefix + item.name;
      if (!this.policy.path_ok(relative)) throw Error('A working filename is not supported on both platforms.');
      if (item.isSymbolicLink()) throw Error('Linked files are not supported in the working folder.');
      if (item.isDirectory()) await this.scanDirectory(connection, join(directory, item.name), relative + '/', collected);
      else if (item.isFile()) collected.push({ connection, path: relative, native: join(directory, item.name) });
    }
    return collected;
  }
  async syncWorking() {
    if (this.paused || !this.config.connections.length) return;
    await this.refresh();
    if (this.view().pending) { await this.finishPending(); return; }
    for (const c of this.view().connections) {
      if (!c.enabled || !this.config.connections.some(local => local.id === c.id)) continue;
      const directory = join(this.folder, String(c.id)); await privateDirectory(directory);
      const seen = new Set();
      for (const local of await this.scanDirectory(c.id, directory)) {
        const key = `${c.id}/${local.path}`;
        seen.add(key);
        try {
          const content = await this.snapshot(local.native), view = this.view();
          const remote = view.files.filter(f => f.connection === c.id && f.path === local.path).at(-1);
          const known = this.local[key];
          const base = known ? view.files.find(f => f.version === known.version && f.connection === c.id && f.path === local.path) : null;
          const action = this.sync.action(snapshot(base), { $: 'Snapshot', kind: 1, version: 0, size: content.size, digest: content.digest }, snapshot(remote));
          this.observations[key] = ['Available offline', 'Local changes', 'Cloud changed', 'Conflict: local and cloud changed'][action];
          if (action === 1) {
            const file = await this.transfer({ connection: c.id, path: local.path, expected: base?.version || 0, source: 0, extra: base ? 0 : c.clearance, kind: 'save' }, content.bytes);
            this.local[key] = { version: file.version, digest: file.digest };
            this.observations[key] = 'Available offline';
          } else if (action === 0 && remote) this.local[key] = { version: remote.version, digest: remote.digest };
          else if (action === 2) {
            // Preserve the original inode under Recovery. Any writer retaining
            // that inode keeps writing its recoverable copy. Install with wx,
            // so a newly created working file always wins the pathname.
            const bytes = await this.fetch(remote), recheck = await this.snapshot(local.native);
            if (recheck.digest !== content.digest || recheck.ino !== content.ino || recheck.dev !== content.dev) throw Error('Local file changed during download; retained.');
            const recovery = join(this.directory, 'Recovery', fresh() + '-' + local.path.split('/').pop());
            await rename(local.native, recovery);
            const fd = await open(local.native, 'wx', 0o600);
            try { await fd.writeFile(bytes); await fd.sync(); } finally { await fd.close(); }
            this.local[key] = { version: remote.version, digest: remote.digest };
            await this.event('downloaded', 'Cloud update applied; previous local inode retained in Recovery.', remote);
          }
        } catch (error) { this.observations[key] = safeMessage(error); this.problem = safeMessage(error); }
      }
      for (const file of this.view().files) {
        const key = `${file.connection}/${file.path}`;
        if (file.connection === c.id && this.local[key] && !seen.has(key))
          this.observations[key] = 'Local file removed; cloud version retained';
      }
    }
    await atomic(join(this.directory, 'local.json'), JSON.stringify(this.local));
  }
  status() {
    const view = this.view();
    const current = new Map(); for (const file of view.files) current.set(`${file.connection}/${file.path}`, file);
    return { connections: view.connections.map(c => ({ ...c, configured: this.config.connections.some(local => local.id === c.id),
      endpoint: this.config.connections.find(local => local.id === c.id)?.endpoint || '',
      bucket: this.config.connections.find(local => local.id === c.id)?.bucket || '' })),
      files: [...current.values()].map(file => ({ ...file, status: this.observations[`${file.connection}/${file.path}`] || (this.local[`${file.connection}/${file.path}`] ? 'Checking local file' : 'Online only') })),
      history: view.files, pending: view.pending, activity: this.activity, folder: this.folder,
      recovery: join(this.directory, 'Recovery'), fetched: this.fetched, sent: this.sent, paused: this.paused, problem: this.problem };
  }
}
