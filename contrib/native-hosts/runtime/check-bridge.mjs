// Native transport probes. Policy assertions live in writfs/MountTests.bend.
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { isAbsolute } from 'node:path';

const modulePath = process.argv[2];
assert.ok(modulePath && isAbsolute(modulePath));
const bridge = fileURLToPath(new URL('./node-policy.mjs', import.meta.url));
const env = {};
for (const key of ['SystemRoot', 'WINDIR', 'TEMP', 'TMP']) {
  if (process.env[key]) env[key] = process.env[key];
}
function invoke(input) {
  return spawnSync(process.execPath, [bridge, modulePath], {
    input, env, timeout: 15000, maxBuffer: 65536, encoding: 'utf8', windowsHide: true,
  });
}
let passed = 0;
function pass(name) { passed++; console.log(`PASS transport ${name}`); }

const status = 'WRITFS1\tSTATUS\t0\t0\t0\t0\t-\n';
const first = invoke(status + status);
assert.equal(first.status, 0);
assert.equal(first.stdout, 'WRITFS1\t1\tOK\t0\tSTATUS\nWRITFS1\t2\tOK\t0\tSTATUS\n');
assert.equal(first.stderr, '');
pass('coalesced frames preserve sequence');

const child = spawn(process.execPath, [bridge, modulePath], { env, stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
let output = '', diagnostics = '';
child.stdout.on('data', chunk => { output += chunk; assert.ok(output.length <= 256); });
child.stderr.on('data', chunk => { diagnostics += chunk; assert.ok(diagnostics.length <= 256); });
const timer = setTimeout(() => child.kill(), 15000);
const ended = new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); });
for (const byte of Buffer.from(status)) child.stdin.write(Buffer.from([byte]));
child.stdin.end();
assert.equal(await ended, 0);
clearTimeout(timer);
assert.equal(output, 'WRITFS1\t1\tOK\t0\tSTATUS\n');
assert.equal(diagnostics, '');
pass('fragmented frame remains one request');

for (const [name, input] of [
  ['unterminated frame', status.slice(0, -1)],
  ['oversized frame', 'x'.repeat(131201) + '\n'],
  ['carriage return', status.replace('\n', '\r\n')],
  ['non-ASCII byte', Buffer.from([0xff, 10])],
  ['NUL byte', Buffer.from([0, 10])],
]) {
  const result = invoke(input);
  assert.equal(result.status, 2, name);
  assert.equal(result.stdout, '', name);
  assert.equal(result.stderr, 'Writ policy transport stopped.\n', name);
  pass(name + ' closes transport');
}

const bytes = Buffer.alloc(65536);
const digest = createHash('sha256').update(bytes).digest('hex');
const maximum = invoke('WRITFS1\tINIT\t0\t0\t0\t0\t' + bytes.toString('hex') + '\n');
assert.equal(maximum.status, 0);
assert.equal(maximum.stdout, `WRITFS1\t1\tOK\t65536\t${digest}\n`);
assert.equal(maximum.stderr, '');
pass('64 KiB frame reaches Bend with exact digest');

const malformed = invoke('WRITFS1\tSTATUS\t00\t0\t0\t0\t-\n' + status);
assert.equal(malformed.status, 0);
assert.equal(malformed.stdout, 'WRITFS1\t1\tERROR\t0\tFRAME\nWRITFS1\t2\tOK\t0\tSTATUS\n');
pass('Bend owns canonical parsing and error sequencing');
console.log(`ALL ${passed} NATIVE TRANSPORT PROBES PASSED`);
