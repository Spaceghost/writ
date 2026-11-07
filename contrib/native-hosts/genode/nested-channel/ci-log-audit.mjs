// Fixed public-fixture evidence matching after full bounded gzip verification.
import fs from 'node:fs';
import path from 'node:path';
import { auditGzip, RAW_CAP, COMPRESSED_CAP } from './ci-gzip.mjs';

if (process.argv.length !== 4) process.exit(2);
const [evidence, scenario] = process.argv.slice(2);
if (!path.isAbsolute(evidence) || !['positive', 'negative'].includes(scenario)) process.exit(2);
const metaPath = path.join(evidence, 'run-meta.json');
const resultPath = path.join(evidence, 'run-audit.json');
const resultTemp = path.join(evidence, 'run-audit.json.tmp');
let result = { audit: 'incomplete', fixture_assertions: 'not_confirmed' };
try {
  const fd = fs.openSync(metaPath, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK);
  let meta;
  try {
    const stat = fs.fstatSync(fd, { bigint: true });
    if (!stat.isFile() || stat.nlink !== 1n || stat.size > 65536n || stat.uid !== BigInt(process.getuid())) {
      throw new Error('invalid metadata file');
    }
    const bytes = Buffer.alloc(65537);
    let used = 0;
    while (used < bytes.length) {
      const count = fs.readSync(fd, bytes, used, bytes.length - used, null);
      if (count === 0) break;
      used += count;
    }
    if (used > 65536 || BigInt(used) !== stat.size) throw new Error('metadata size changed or exceeded limit');
    meta = JSON.parse(bytes.subarray(0, used).toString('utf8'));
    const after = fs.fstatSync(fd, { bigint: true });
    if (stat.dev !== after.dev || stat.ino !== after.ino || stat.mode !== after.mode ||
        stat.uid !== after.uid || stat.nlink !== after.nlink || stat.size !== after.size ||
        stat.mtimeNs !== after.mtimeNs || stat.ctimeNs !== after.ctimeNs) {
      throw new Error('metadata changed during read');
    }
  } finally { fs.closeSync(fd); }
  if (meta.capture !== 'complete' || !meta.complete || meta.raw_cap !== RAW_CAP || meta.compressed_cap !== COMPRESSED_CAP ||
      !meta.raw || !meta.compressed || !meta.child || !Number.isSafeInteger(meta.raw.bytes) ||
      !Number.isSafeInteger(meta.compressed.bytes) || meta.raw.bytes < 0 || meta.raw.bytes > RAW_CAP ||
      meta.compressed.bytes < 18 || meta.compressed.bytes > COMPRESSED_CAP ||
      !/^[0-9a-f]{64}$/.test(meta.raw.sha256) || !/^[0-9a-f]{64}$/.test(meta.compressed.sha256)) {
    throw new Error('capture metadata incomplete or invalid');
  }
  const needles = scenario === 'positive'
    ? ['nested public R fixture: PASS']
    : ['[init -> writ_bend_monitor] writ_channel: service announced',
      '[init -> writ_bend_monitor] monitor: SYNTHETIC authority',
      '[init -> clients] \x1b[34mWarning: writ_client_r: no route to service "Writ_channel" (label="writ_client_r -> channel")\x1b[0m',
      '[init -> clients -> writ_client_r] \x1b[31mError: stop because parent denied Writ_channel-session:',
      'nested public R route-negative fixture: PASS'];
  const checked = await auditGzip(path.join(evidence, 'run.log.gz'), meta, needles);
  const expectedExit = meta.child.code === 0;
  const matched = expectedExit && meta.child.signal === null && checked.found.every(Boolean);
  result = { audit: 'complete', fixture_assertions: matched ? 'matched' : 'not_confirmed',
    raw: checked.raw, compressed: checked.compressed, child: meta.child, matched_lines: checked.found };
} catch (error) {
  result.reason = String(error.message);
}
try {
  fs.writeFileSync(resultTemp, JSON.stringify(result, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
  fs.linkSync(resultTemp, resultPath);
  fs.unlinkSync(resultTemp);
} catch (error) {
  console.error('INCOMPLETE: cannot finalize audit:', error.message);
  process.exit(1);
}
if (result.audit !== 'complete' || result.fixture_assertions !== 'matched') {
  console.error('INCOMPLETE: fixture assertions not confirmed');
  process.exit(1);
}
