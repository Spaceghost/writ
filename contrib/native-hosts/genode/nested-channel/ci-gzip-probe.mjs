// Offline native I/O probes only; own temporary files and synthetic child processes.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import { Readable } from 'node:stream';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { compressRaw, auditGzip } from './ci-gzip.mjs';
import { captureToFiles } from './ci-capture-core.mjs';

const root = fs.mkdtempSync('/tmp/writ-gzip-probe-');
const here = path.dirname(fileURLToPath(import.meta.url));
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
const requireTrue = (condition, message) => { if (!condition) throw new Error(message); };
async function rejects(fn, message) {
  try { await fn(); } catch { console.log(`${message}: refused`); return; }
  throw new Error(`${message}: unexpectedly accepted`);
}
async function capture(name, chunks, rawCap = 1048576, compressedCap = 1048576) {
  const p = path.join(root, name);
  const m = await compressRaw(Readable.from(chunks), p, rawCap, compressedCap);
  return { p, m };
}
try {
  for (const [name, chunks] of [
    ['empty', []], ['multichunk', [Buffer.from('synthetic '), Buffer.from([0xff, 0x00]), Buffer.from(' data')]],
    ['warnings', [Buffer.from('warning: retained\n'.repeat(2000))]], ['incompressible', [crypto.randomBytes(32768)]],
  ]) {
    const raw = Buffer.concat(chunks); const { p, m } = await capture(name, chunks);
    requireTrue(m.complete && m.raw.bytes === raw.length && m.raw.sha256 === digest(raw), `${name} capture`);
    requireTrue(zlib.gunzipSync(fs.readFileSync(p)).equals(raw), `${name} original bytes`);
    const a = await auditGzip(p, m, [], 1048576, 1048576);
    requireTrue(a.complete && a.raw.sha256 === digest(raw), `${name} audit`);
    console.log(`${name}: complete bytes verified`);
  }
  let exact = await capture('raw-exact', [Buffer.alloc(1024)], 1024, 1048576);
  requireTrue(exact.m.complete, 'exact raw cap');
  let over = await capture('raw-over', [Buffer.from('success-marker'), Buffer.alloc(1024)], 1024, 1048576);
  requireTrue(!over.m.complete && over.m.reason.includes('raw cap'), 'raw overflow');
  console.log('raw cap and success-before-overflow: incomplete on overflow');
  const sample = Buffer.from('compressible fixed sample');
  const estimated = zlib.gzipSync(sample).length;
  exact = await capture('compressed-exact', [sample], 1024, estimated);
  over = await capture('compressed-over', [sample], 1024, estimated - 1);
  requireTrue(exact.m.complete && !over.m.complete && over.m.reason.includes('compressed cap'), 'compressed cap');
  console.log('compressed cap: exact accepted, one-byte-over refused');
  const good = await capture('good', [Buffer.from('first synthetic member')]);
  const first = fs.readFileSync(good.p);
  for (const [name, payload] of [
    ['truncated', first.subarray(0, first.length - 1)],
    ['concat', Buffer.concat([first, zlib.gzipSync(Buffer.from('second'))])],
    ['trailing', Buffer.concat([first, Buffer.from('trailing')])],
    ['bad-crc', Buffer.concat([first.subarray(0, first.length - 8), Buffer.alloc(8)])],
  ]) {
    const p = path.join(root, name); fs.writeFileSync(p, payload);
    const m = { ...good.m, compressed: { bytes: payload.length, sha256: digest(payload) } };
    await rejects(() => auditGzip(p, m, [], 1048576, 1048576), name);
  }
  await rejects(() => auditGzip(good.p, { ...good.m, raw: { ...good.m.raw, sha256: '0'.repeat(64) } }, [], 1048576, 1048576), 'wrong raw hash');
  await rejects(() => auditGzip(good.p, good.m, [], 4, 1048576), 'decompression cap');
  const failed = await compressRaw(Readable.from([Buffer.from('x')]), path.join(root, 'missing', 'x'), 1024, 1024);
  requireTrue(!failed.complete, 'destination failure'); console.log('destination failure: incomplete');
  const diskChild = path.join(root, 'disk-child.mjs');
  fs.writeFileSync(diskChild, `import {Readable} from 'node:stream'; import {randomBytes} from 'node:crypto'; import {compressRaw} from ${JSON.stringify(new URL('./ci-gzip.mjs', import.meta.url).href)}; const r=await compressRaw(Readable.from([randomBytes(65536)]),${JSON.stringify(path.join(root,'disk-limited'))},1048576,1048576); if(r.complete) process.exit(1); console.log('limited file write: incomplete');`);
  const disk = spawnSync('/bin/bash', ['-c', 'ulimit -f 1; exec "$1" "$2"', 'writ-test', process.execPath, diskChild],
    {timeout:10000,encoding:'utf8'});
  requireTrue(disk.status === 0 && disk.stdout.includes('limited file write: incomplete'), `disk write failure: ${disk.status} ${disk.stderr}`);
  console.log('synthetic disk write failure: incomplete');
  const big = await capture('mutation', [crypto.randomBytes(8 * 1024 * 1024)], 16 * 1024 * 1024, 16 * 1024 * 1024);
  requireTrue(big.m.complete, 'mutation setup');
  const before = fs.statSync(big.p, { bigint: true });
  const pending = auditGzip(big.p, big.m, [], 16 * 1024 * 1024, 16 * 1024 * 1024);
  setImmediate(() => { const fd = fs.openSync(big.p, 'r+'); try { fs.writeSync(fd, Buffer.from([0x55]), 0, 1, 4); } finally { fs.closeSync(fd); } });
  await rejects(() => pending, 'same-inode rewrite');
  requireTrue(fs.statSync(big.p, { bigint: true }).ino === before.ino, 'mutation changed inode');
  const driver = path.join(here, 'ci-log-collect.mjs'); const auditor = path.join(here, 'ci-log-audit.mjs');
  const signalDir=path.join(root,'signal-status'); fs.mkdirSync(signalDir);
  const signalCapture=await captureToFiles(Readable.from([Buffer.from('nested public R fixture: PASS')]),
    Promise.resolve({code:null,signal:'SIGTERM'}), path.join(signalDir,'run.log.gz.partial'),
    path.join(signalDir,'run.log.gz'), path.join(signalDir,'run-meta.json'));
  requireTrue(signalCapture, 'synthetic signaled producer capture');
  const signalAudit=spawnSync(process.execPath,[auditor,signalDir,'positive'],{encoding:'utf8',timeout:10000});
  requireTrue(signalAudit.status===1, 'signaled producer was mistaken for success');
  console.log('producer signal status: not confirmed');
  const failedSpawnDir = path.join(root, 'failed-spawn'); fs.mkdirSync(failedSpawnDir);
  const failedSpawn = await captureToFiles(Readable.from([Buffer.from('synthetic')]), Promise.reject(new Error('synthetic spawn error')),
    path.join(failedSpawnDir, 'partial'), path.join(failedSpawnDir, 'complete'), path.join(failedSpawnDir, 'meta'), 1024, 1024);
  requireTrue(!failedSpawn && JSON.parse(fs.readFileSync(path.join(failedSpawnDir, 'meta'))).capture === 'incomplete', 'failed spawn');
  console.log('failed spawn: incomplete metadata retained');
  const ignoreDir = path.join(root, 'ignore-epipe'); fs.mkdirSync(ignoreDir);
  const writer = spawn(process.execPath, ['-e', `process.stdout.on('error', () => {}); const t=setInterval(() => process.stdout.write(Buffer.alloc(1024)), 1); setTimeout(() => { clearInterval(t); process.exit(0); }, 1500);`], { stdio: ['ignore', 'pipe', 'ignore'] });
  const writerExit = new Promise((resolve, reject) => { writer.once('error', reject); writer.once('exit', (code, signal) => resolve({code, signal})); });
  let writerExited = false;
  writerExit.then(() => { writerExited = true; }, () => { writerExited = true; });
  const ignored = await captureToFiles(writer.stdout, writerExit, path.join(ignoreDir, 'run.log.gz.partial'),
    path.join(ignoreDir, 'run.log.gz'), path.join(ignoreDir, 'run-meta.json'), 4096, 1048576);
  const ignoredMeta = JSON.parse(fs.readFileSync(path.join(ignoreDir, 'run-meta.json')));
  requireTrue(!ignored && ignoredMeta.capture === 'incomplete' && ignoredMeta.child_status === 'not_waited_after_capture_failure' &&
    !writerExited, 'cap plus writer ignoring EPIPE');
  const incompleteAudit = spawnSync(process.execPath, [auditor, ignoreDir, 'positive'], { timeout: 10000 });
  requireTrue(incompleteAudit.status === 1 && JSON.parse(fs.readFileSync(path.join(ignoreDir, 'run-audit.json'))).fixture_assertions === 'not_confirmed',
    'overflow metadata was mistaken for a fixture success');
  await writerExit; // The test-owned synthetic child exits naturally; no kill.
  console.log('cap with writer ignoring EPIPE: failure metadata published promptly');
  for (const [name, content] of [['bad-json','{'], ['empty-meta','{}'], ['large-meta','x'.repeat(65537)]]) {
    const dir=path.join(root,name); fs.mkdirSync(dir); fs.writeFileSync(path.join(dir,'run-meta.json'),content);
    const checked=spawnSync(process.execPath,[auditor,dir,'positive'],{encoding:'utf8',timeout:10000});
    const result=JSON.parse(fs.readFileSync(path.join(dir,'run-audit.json')));
    requireTrue(checked.status===1 && result.fixture_assertions==='not_confirmed', `${name}: metadata was accepted`);
    console.log(`${name}: not confirmed`);
  }
  for (const [name, body, code, expected] of [
    ['good-positive', 'nested public R fixture: PASS', 0, 0],
    ['bad-exit', 'nested public R fixture: PASS', 7, 1],
    ['missing-marker', 'no fixture marker', 0, 1],
  ]) {
    const dir=path.join(root,name), evidence=path.join(dir,'evidence');
    fs.mkdirSync(dir); fs.mkdirSync(evidence);
    const payload=Buffer.from(body+'\n').toString('base64');
    fs.writeFileSync(path.join(dir,'Makefile'), `run/writ_bend_monitor_nested_accept:\n\t@printf '%s' '${payload}' | base64 -d; exit ${code}\n`);
    const env={ PATH: '/usr/bin:/bin', HOME: root };
    const collect=spawnSync(process.execPath,[driver,dir,evidence],{env,encoding:'utf8',timeout:10000});
    requireTrue(collect.status===0, `${name}: capture failed ${collect.stderr}`);
    const checked=spawnSync(process.execPath,[auditor,evidence,'positive'],{env,encoding:'utf8',timeout:10000});
    requireTrue(checked.status===expected, `${name}: incorrect audit ${checked.status}`);
    console.log(`${name}: ${expected===0?'matched':'not confirmed'}`);
  }
  const markers = ['decision=Committed reason=0', 'client: FAIL expected decision 2 reason 0, observed decision 1 reason 0',
    'child "writ_client_r" exited with exit value 1', 'Error: nested client did not exit with value 0'];
  const controls = [['negative-full', markers, 2, 0], ['negative-exit-zero', markers, 0, 1],
    ['negative-unrelated-failure', ['unrelated build failure'], 2, 1],
    ...markers.map((_, i) => [`negative-missing-${i}`, markers.filter((__, j) => i !== j), 2, 1])];
  for (const [name, lines, code, expected] of controls) {
    const dir=path.join(root,name), evidence=path.join(dir,'evidence');
    fs.mkdirSync(dir); fs.mkdirSync(evidence);
    const payload=Buffer.from(lines.join('\n')+'\n').toString('base64');
    fs.writeFileSync(path.join(dir,'Makefile'), `run/writ_bend_monitor_nested_accept:\n\t@printf '%s' '${payload}' | base64 -d; exit ${code}\n`);
    const env={ PATH: '/usr/bin:/bin', HOME: root };
    const collected=spawnSync(process.execPath,[driver,dir,evidence],{env,encoding:'utf8',timeout:10000});
    requireTrue(collected.status===0, `${name}: capture failed ${collected.stderr}`);
    const checked=spawnSync(process.execPath,[auditor,evidence,'negative'],{env,encoding:'utf8',timeout:10000});
    requireTrue(checked.status===expected, `${name}: incorrect audit ${checked.status}`);
    console.log(`${name}: ${expected===0?'matched':'not confirmed'}`);
  }
} finally { fs.rmSync(root, {recursive:true, force:true}); }
