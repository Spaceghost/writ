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
  'config-sha256.txt', 'negative.diff', 'build.conf', 'tools.conf', 'build-config-sha256.txt', 'run.log',
  'run-status.txt', 'run-sha256.txt', 'boot-inputs-sha256.txt', 'installed-config.txt', 'observed.txt',
  'fixture-post-status.txt', 'fixture-post-manifest.txt', 'setup.log', 'driver-status.txt',
];
const { O_RDONLY, O_WRONLY, O_CREAT, O_EXCL, O_NOFOLLOW, O_NONBLOCK, O_DIRECTORY } = fs.constants;
const limit = 32 * 1024 * 1024;
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
    try {
      const source = `/proc/self/fd/${rawFd}/${name}`;
      sourceFd = fs.openSync(source, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
      const before = fs.fstatSync(sourceFd, { bigint: true });
      if (!before.isFile() || before.uid !== raw.uid || before.dev !== raw.dev ||
          before.nlink !== 1n || before.size > BigInt(limit)) {
        throw new Error('not an owned, single-link, bounded regular file on the expected device');
      }
      const chunks = [];
      let total = 0;
      while (true) {
        const buffer = Buffer.allocUnsafe(65536);
        const n = fs.readSync(sourceFd, buffer, 0, buffer.length, null);
        if (n === 0) break;
        total += n;
        if (total > limit) throw new Error('size limit exceeded while reading');
        chunks.push(buffer.subarray(0, n));
      }
      const after = fs.fstatSync(sourceFd, { bigint: true });
      if (before.dev !== after.dev || before.ino !== after.ino || before.uid !== after.uid ||
          before.nlink !== after.nlink || before.mode !== after.mode || before.size !== after.size ||
          before.mtimeNs !== after.mtimeNs || before.ctimeNs !== after.ctimeNs || BigInt(total) !== after.size) {
        throw new Error('file changed during snapshot');
      }
      const data = Buffer.concat(chunks, total);
      destinationFd = fs.openSync(`/proc/self/fd/${outputFd}/${name}`, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600);
      fs.writeFileSync(destinationFd, data);
      output.push({ name, status: 'snapshot', bytes: total, sha256: crypto.createHash('sha256').update(data).digest('hex') });
    } catch (error) {
      if (error.code === 'ENOENT' && name === 'negative.diff' && scenario === 'positive') {
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
  const resultFd = fs.openSync(`/proc/self/fd/${outputFd}/snapshot-result.json`, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600);
  try { fs.writeFileSync(resultFd, JSON.stringify({ observation: 'bounded snapshots; cleanup unverified', files: output }, null, 2) + '\n'); }
  finally { fs.closeSync(resultFd); }
} catch (error) {
  refused = true;
  console.error('INCOMPLETE: snapshot setup failed:', error.message);
} finally {
  if (rawFd !== undefined) fs.closeSync(rawFd);
  if (outputFd !== undefined) fs.closeSync(outputFd);
}
process.exit(refused ? 1 : 0);
