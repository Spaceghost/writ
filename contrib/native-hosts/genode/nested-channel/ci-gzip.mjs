// Bounded gzip I/O for the disposable public-fixture harness. No policy or authority.
import fs from 'node:fs';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import { Transform, Writable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

export const RAW_CAP = 512 * 1024 * 1024;
export const COMPRESSED_CAP = 520 * 1024 * 1024;
const CHUNK = 64 * 1024;
const { O_RDONLY, O_NOFOLLOW, O_NONBLOCK } = fs.constants;

function counter(cap, label) {
  let size = 0;
  const hash = crypto.createHash('sha256');
  const stream = new Transform({
    transform(chunk, _encoding, done) {
      if (size + chunk.length > cap) return done(new Error(`${label} cap exceeded`));
      size += chunk.length;
      hash.update(chunk);
      done(null, chunk);
    },
  });
  return { stream, result: () => ({ bytes: size, sha256: hash.copy().digest('hex') }) };
}

export async function compressRaw(input, partialPath, rawCap = RAW_CAP, compressedCap = COMPRESSED_CAP) {
  const raw = counter(rawCap, 'raw');
  const compressed = counter(compressedCap, 'compressed');
  try {
    await pipeline(input, raw.stream, zlib.createGzip(), compressed.stream,
      fs.createWriteStream(partialPath, { flags: 'wx', mode: 0o600 }));
    return { complete: true, raw: raw.result(), compressed: compressed.result() };
  } catch (error) {
    return { complete: false, reason: String(error.message),
      raw_processed_before_failure: raw.result(), compressed_processed_before_failure: compressed.result(),
      partial_file_hash: 'deferred_to_bounded_snapshot' };
  }
}

function hashFd(fd, size) {
  const hash = crypto.createHash('sha256');
  const buffer = Buffer.allocUnsafe(CHUNK);
  let offset = 0;
  while (offset < size) {
    const n = fs.readSync(fd, buffer, 0, Math.min(buffer.length, size - offset), offset);
    if (!n) throw new Error('compressed file shortened while hashing');
    hash.update(buffer.subarray(0, n));
    offset += n;
  }
  return hash.digest('hex');
}

function sameStat(a, b) {
  return a.dev === b.dev && a.ino === b.ino && a.mode === b.mode && a.uid === b.uid &&
    a.nlink === b.nlink && a.size === b.size && a.mtimeNs === b.mtimeNs && a.ctimeNs === b.ctimeNs;
}

async function inflatePass(fd, transform, cap, needles = []) {
  const sha = crypto.createHash('sha256');
  const found = needles.map(() => false);
  const maxNeedle = Math.max(1, ...needles.map(n => Buffer.byteLength(n)));
  const strings = needles.map(n => Buffer.from(n));
  let carry = Buffer.alloc(0), bytes = 0;
  const sink = new Writable({
    write(chunk, _encoding, done) {
      if (bytes + chunk.length > cap) return done(new Error('decompressed cap exceeded'));
      bytes += chunk.length;
      sha.update(chunk);
      if (strings.length) {
        const window = Buffer.concat([carry, chunk]);
        for (let i = 0; i < strings.length; i++) if (window.includes(strings[i])) found[i] = true;
        carry = window.subarray(Math.max(0, window.length - (maxNeedle - 1)));
      }
      done();
    },
  });
  // createReadStream uses position-specific reads; autoClose:false preserves fd identity.
  await pipeline(fs.createReadStream(null, { fd, autoClose: false, start: transform instanceof zlib.InflateRaw ? 10 : 0,
    highWaterMark: CHUNK }), transform, sink);
  return { bytes, sha256: sha.digest('hex'), found };
}

export async function auditGzip(path, expected, needles = [], rawCap = RAW_CAP, compressedCap = COMPRESSED_CAP) {
  const fd = fs.openSync(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
  try {
    const before = fs.fstatSync(fd, { bigint: true });
    if (!before.isFile() || before.nlink !== 1n || before.uid !== BigInt(process.getuid()) ||
        before.size < 18n || before.size > BigInt(compressedCap)) throw new Error('invalid compressed file');
    const size = Number(before.size);
    const compressedSha = hashFd(fd, size);
    if (size !== expected.compressed.bytes || compressedSha !== expected.compressed.sha256) {
      throw new Error('compressed identity mismatch');
    }
    const header = Buffer.alloc(10);
    if (fs.readSync(fd, header, 0, header.length, 0) !== 10 ||
        header[0] !== 0x1f || header[1] !== 0x8b || header[2] !== 8 || header[3] !== 0) {
      throw new Error('unsupported gzip header');
    }
    // InflateRaw stops at the end of the first deflate stream. Exactly eight
    // remaining bytes must be its gzip trailer: no second member or garbage.
    const rawInflater = zlib.createInflateRaw();
    const rawPass = await inflatePass(fd, rawInflater, rawCap);
    if (10 + rawInflater.bytesWritten + 8 !== size) throw new Error('extra or missing gzip bytes');
    // Gunzip checks CRC32/trailer; the second pass also hashes exactly parsed bytes.
    const checked = await inflatePass(fd, zlib.createGunzip(), rawCap, needles);
    if (rawPass.bytes !== expected.raw.bytes || rawPass.sha256 !== expected.raw.sha256 ||
        checked.bytes !== expected.raw.bytes || checked.sha256 !== expected.raw.sha256) {
      throw new Error('decompressed identity mismatch');
    }
    if (!sameStat(before, fs.fstatSync(fd, { bigint: true })) || hashFd(fd, size) !== compressedSha) {
      throw new Error('compressed file changed during audit');
    }
    return { complete: true, raw: { bytes: checked.bytes, sha256: checked.sha256 },
      compressed: { bytes: size, sha256: compressedSha }, found: checked.found };
  } finally { fs.closeSync(fd); }
}
