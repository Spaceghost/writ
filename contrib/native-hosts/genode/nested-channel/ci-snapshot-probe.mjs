// Native I/O-only synthetic probe for the public-evidence snapshot helper.
// Creates and removes only its own private /tmp tree; no Genode or host scan.
import fs from 'node:fs';
import { spawnSync, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const script = fileURLToPath(new URL('./ci-snapshot.mjs', import.meta.url));
const names = ['identity.txt','input-sha256.txt','tool-identity.txt','clang-resource-sha256.txt',
  'genode-git-status.txt','genode-archive-comparison.txt','genode-archive-git-status.txt','genode-commit.txt',
  'environment.txt','source-sha256.txt','overlay-sha256.txt','generated-sha256.txt','original.run','actual.run',
  'config-sha256.txt','negative.diff','build.conf','tools.conf','build-config-sha256.txt','run.log',
  'run-status.txt','run-sha256.txt','boot-inputs-sha256.txt','installed-config.txt','observed.txt',
  'fixture-post-status.txt','fixture-post-manifest.txt','setup.log','driver-status.txt'];
const root = fs.mkdtempSync('/tmp/writ-snapshot-probe-');
try {
  for (const kind of ['positive','negative','missing','symlink','fifo','hardlink','oversize','wrong-directory']) {
    const dir = path.join(root, kind); const raw = path.join(dir, 'raw'); const out = path.join(dir, 'out');
    fs.mkdirSync(dir); fs.mkdirSync(raw); fs.mkdirSync(out);
    for (const name of names) {
      if (!(name === 'negative.diff' && kind === 'positive')) fs.writeFileSync(path.join(raw, name), 'synthetic\n');
    }
    const log = path.join(raw, 'run.log');
    if (kind === 'missing') fs.unlinkSync(log);
    if (kind === 'symlink') { fs.unlinkSync(log); fs.writeFileSync(path.join(dir, 'sentinel'), 'private synthetic\n'); fs.symlinkSync(path.join(dir, 'sentinel'), log); }
    if (kind === 'fifo') { fs.unlinkSync(log); execFileSync('mkfifo', [log]); }
    if (kind === 'hardlink') { fs.unlinkSync(log); fs.writeFileSync(path.join(dir, 'sentinel'), 'synthetic\n'); fs.linkSync(path.join(dir, 'sentinel'), log); }
    if (kind === 'oversize') fs.truncateSync(log, 33554433);
    const stat = fs.statSync(raw, { bigint: true });
    const id = kind === 'wrong-directory' ? `${stat.dev}:${stat.ino + 1n}:${stat.uid}` : `${stat.dev}:${stat.ino}:${stat.uid}`;
    const result = spawnSync(process.execPath, [script, raw, out, id, kind === 'positive' ? 'positive' : 'negative'],
      { timeout: 5000, encoding: 'utf8' });
    const expected = kind === 'positive' || kind === 'negative' ? 0 : 1;
    if (result.status !== expected) throw new Error(`${kind}: expected ${expected}, observed ${result.status}: ${result.stderr}`);
    if (kind === 'symlink' && fs.existsSync(path.join(out, 'run.log'))) throw new Error('symlink target was copied');
    console.log(`${kind}: ${expected === 0 ? 'accepted' : 'refused'}`);
  }
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}
