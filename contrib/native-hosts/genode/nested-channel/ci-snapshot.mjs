// Bounded public evidence I/O only. This does not launch, signal or verify cleanup.
import fs from 'node:fs';
import crypto from 'node:crypto';

if (process.argv.length !== 6) process.exit(2);
const [rawPath, outputPath, expectedDirectory, scenario] = process.argv.slice(2);
if (scenario !== 'positive' && scenario !== 'negative') process.exit(2);
const names = [
  'identity.txt', 'input-sha256.txt', 'tool-identity.txt', 'clang-resource-sha256.txt',
  'genode-git-status.txt', 'genode-archive-comparison.txt', 'genode-archive-git-status.txt', 'genode-commit.txt',
  'environment.txt', 'source-sha256.txt', 'overlay-sha256.txt', 'generated-sha256.txt', 'original.run', 'actual.run',
  'config-sha256.txt', 'negative.diff', 'build.conf', 'tools.conf', 'build-config-sha256.txt',
  'run.log.gz', 'run.log.gz.partial', 'run-meta.json', 'run-audit.json', 'run-status.txt',
  'boot-inputs-sha256.txt', 'installed-config.txt', 'observed.txt',
  'fixture-post-status.txt', 'fixture-post-manifest.txt', 'setup.log', 'driver-status.txt',
];
const { O_RDONLY, O_WRONLY, O_CREAT, O_EXCL, O_NOFOLLOW, O_NONBLOCK, O_DIRECTORY } = fs.constants;
const output = [];
let refused = false;
const dirFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW;
let rawFd, outputFd;
try {
  rawFd = fs.openSync(rawPath, dirFlags);
  outputFd = fs.openSync(outputPath, dirFlags);
  const raw = fs.fstatSync(rawFd, { bigint: true });
  const out = fs.fstatSync(outputFd, { bigint: true });
  if (!raw.isDirectory() || !out.isDirectory() || raw.uid !== BigInt(process.getuid()) ||
      out.uid !== BigInt(process.getuid()) ||
      `${raw.dev}:${raw.ino}:${raw.uid}` !== expectedDirectory) {
    throw new Error('directory identity or owner mismatch');
  }
  for (const name of names) {
    let sourceFd, destinationFd;
    let destinationCreated = false;
    const staged = `/proc/self/fd/${outputFd}/.${name}.snapshot.tmp`;
    const final = `/proc/self/fd/${outputFd}/${name}`;
    try {
      const limit = name === 'run.log.gz' || name === 'run.log.gz.partial' ? 520 * 1024 * 1024 : 32 * 1024 * 1024;
      const source = `/proc/self/fd/${rawFd}/${name}`;
      sourceFd = fs.openSync(source, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
      const before = fs.fstatSync(sourceFd, { bigint: true });
      if (!before.isFile() || before.uid !== raw.uid || before.dev !== raw.dev ||
          before.nlink !== 1n || before.size > BigInt(limit)) {
        throw new Error('not an owned, single-link, bounded regular file on the expected device');
      }
      const hash = crypto.createHash('sha256');
      destinationFd = fs.openSync(staged, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600);
      destinationCreated = true;
      let total = 0;
      while (true) {
        const buffer = Buffer.allocUnsafe(65536);
        const n = fs.readSync(sourceFd, buffer, 0, buffer.length, null);
        if (n === 0) break;
        total += n;
        if (total > limit) throw new Error('size limit exceeded while reading');
        hash.update(buffer.subarray(0, n));
        let offset = 0;
        while (offset < n) {
          const written = fs.writeSync(destinationFd, buffer, offset, n - offset);
          if (written <= 0) throw new Error('snapshot write made no progress');
          offset += written;
        }
      }
      const after = fs.fstatSync(sourceFd, { bigint: true });
      if (before.dev !== after.dev || before.ino !== after.ino || before.uid !== after.uid ||
          before.nlink !== after.nlink || before.mode !== after.mode || before.size !== after.size ||
          before.mtimeNs !== after.mtimeNs || before.ctimeNs !== after.ctimeNs || BigInt(total) !== after.size) {
        throw new Error('file changed during snapshot');
      }
      fs.closeSync(destinationFd);
      destinationFd = undefined;
      if (name !== 'run.log.gz') {
        fs.linkSync(staged, final); // promote only a verified and closed file
        fs.unlinkSync(staged);
      }
      // The complete gzip stays staged until its audit binding also succeeds.
      destinationCreated = false;
      output.push({ name, status: 'snapshot', bytes: total, sha256: hash.digest('hex') });
    } catch (error) {
      if (destinationCreated) {
        try { fs.unlinkSync(staged); } catch { /* still incomplete */ }
      }
      if (error.code === 'ENOENT' && ((name === 'negative.diff' && scenario === 'positive') || name === 'run.log.gz.partial')) {
        output.push({ name, status: 'not-applicable' });
      }
      else {
        refused = true;
        output.push({ name, status: 'refused', reason: String(error.message) });
      }
    } finally {
      if (sourceFd !== undefined) fs.closeSync(sourceFd);
      if (destinationFd !== undefined) fs.closeSync(destinationFd);
    }
  }
  // Bind the bytes being uploaded to the preceding capture and audit. This is
  // a snapshot-time check, not attestation against adaptive same-UID races.
  const row = name => output.find(item => item.name === name && item.status === 'snapshot');
  function jsonSnapshot(name) {
    const recorded = row(name);
    if (!recorded || recorded.bytes > 65536) throw new Error(`missing or oversized ${name}`);
    const fd = fs.openSync(`/proc/self/fd/${outputFd}/${name}`, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
    try {
      const st = fs.fstatSync(fd, { bigint: true });
      if (!st.isFile() || st.size !== BigInt(recorded.bytes) || st.nlink !== 1n || st.uid !== out.uid) {
        throw new Error(`changed ${name}`);
      }
      const data = Buffer.alloc(recorded.bytes + 1);
      let used = 0;
      while (used < data.length) {
        const count = fs.readSync(fd, data, used, data.length - used, null);
        if (!count) break;
        used += count;
      }
      if (used !== recorded.bytes || crypto.createHash('sha256').update(data.subarray(0, used)).digest('hex') !== recorded.sha256) {
        throw new Error(`changed ${name}`);
      }
      return JSON.parse(data.subarray(0, used).toString('utf8'));
    } finally { fs.closeSync(fd); }
  }
  const gzip = row('run.log.gz');
  if (gzip) {
    const stagedGzip = `/proc/self/fd/${outputFd}/.run.log.gz.snapshot.tmp`;
    let promoted = false;
    try {
      const capture = jsonSnapshot('run-meta.json');
      const audit = jsonSnapshot('run-audit.json');
      if (capture.capture !== 'complete' || audit.audit !== 'complete' ||
          capture.compressed?.bytes !== gzip.bytes || audit.compressed?.bytes !== gzip.bytes ||
          capture.compressed?.sha256 !== gzip.sha256 || audit.compressed?.sha256 !== gzip.sha256 ||
          !Number.isSafeInteger(capture.raw?.bytes) || capture.raw.bytes < 0 || capture.raw.bytes > 512 * 1024 * 1024 ||
          !/^[0-9a-f]{64}$/.test(capture.raw?.sha256 || '') ||
          capture.raw?.bytes !== audit.raw?.bytes || capture.raw?.sha256 !== audit.raw?.sha256) {
        throw new Error('captured log does not match its audit');
      }
      const fd = fs.openSync(stagedGzip, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
      try {
        const before = fs.fstatSync(fd, { bigint: true });
        if (!before.isFile() || before.uid !== out.uid || before.dev !== out.dev || before.nlink !== 1n || before.size !== BigInt(gzip.bytes)) {
          throw new Error('staged gzip identity changed');
        }
        const hash = crypto.createHash('sha256');
        const buffer = Buffer.allocUnsafe(65536);
        let total = 0;
        while (true) {
          const count = fs.readSync(fd, buffer, 0, buffer.length, null);
          if (!count) break;
          total += count;
          if (total > gzip.bytes) throw new Error('staged gzip grew');
          hash.update(buffer.subarray(0, count));
        }
        const after = fs.fstatSync(fd, { bigint: true });
        if (total !== gzip.bytes || hash.digest('hex') !== gzip.sha256 ||
            before.dev !== after.dev || before.ino !== after.ino || before.mode !== after.mode ||
            before.uid !== after.uid || before.nlink !== after.nlink || before.size !== after.size ||
            before.mtimeNs !== after.mtimeNs || before.ctimeNs !== after.ctimeNs) {
          throw new Error('staged gzip changed before promotion');
        }
      } finally { fs.closeSync(fd); }
      fs.linkSync(stagedGzip, `/proc/self/fd/${outputFd}/run.log.gz`);
      promoted = true;
      fs.unlinkSync(stagedGzip);
    } catch (error) {
      refused = true;
      gzip.status = 'refused';
      gzip.reason = String(error.message);
      if (promoted) {
        try { fs.unlinkSync(`/proc/self/fd/${outputFd}/run.log.gz`); } catch { /* still incomplete */ }
      }
      try {
        fs.linkSync(stagedGzip, `/proc/self/fd/${outputFd}/run.log.gz.unverified`);
        gzip.retained_as = 'run.log.gz.unverified';
      } catch { /* Missing unverified bytes remain incomplete. */ }
      try { fs.unlinkSync(stagedGzip); } catch { /* still incomplete */ }
    }
  }
  const resultStage = `/proc/self/fd/${outputFd}/.snapshot-result.json.snapshot.tmp`;
  const resultFd = fs.openSync(resultStage, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600);
  try { fs.writeFileSync(resultFd, JSON.stringify({ observation: 'bounded snapshots; cleanup unverified', files: output }, null, 2) + '\n'); }
  finally { fs.closeSync(resultFd); }
  fs.linkSync(resultStage, `/proc/self/fd/${outputFd}/snapshot-result.json`);
  fs.unlinkSync(resultStage);
} catch (error) {
  refused = true;
  console.error('INCOMPLETE: snapshot setup failed:', error.message);
} finally {
  if (rawFd !== undefined) fs.closeSync(rawFd);
  if (outputFd !== undefined) fs.closeSync(outputFd);
}
process.exit(refused ? 1 : 0);
