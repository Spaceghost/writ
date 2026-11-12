#!/usr/bin/env node
// Local desktop control transport. Presentation is untrusted input: authority
// comes only from the owner's configured broker and its generated Bend state.
import { createServer } from 'node:http';
import { readFile, unlink, open } from 'node:fs/promises';
import { join, dirname, resolve } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { Broker, privateDirectory, openNative, safeMessage } from './broker.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const option = (name, fallback) => { const at = args.indexOf(name); return at < 0 ? fallback : args[at + 1]; };
const data = resolve(option('--data', join(process.env.LOCALAPPDATA || process.env.XDG_DATA_HOME || join(homedir(), '.local', 'share'), 'WritDrive')));
const folder = resolve(option('--folder', join(homedir(), 'Writ Drive')));
const policyDir = resolve(option('--policy', here));
const { default: policy } = await import(pathToFileURL(join(policyDir, 'drive.mjs')).href);
const { default: sync } = await import(pathToFileURL(join(policyDir, 'directory-sync.mjs')).href);
await privateDirectory(data);
const sessionPath = join(data, 'session.json');
try {
  const session = JSON.parse(await readFile(sessionPath, 'utf8'));
  let live = true; try { process.kill(session.pid, 0); } catch (error) { if (error.code === 'ESRCH') live = false; else throw error; }
  if (live) {
    if (!/^http:\/\/127\.0\.0\.1:\d+\/#token=[0-9a-f]{64}$/.test(session.url)) throw Error('Invalid existing app session.');
    if (args.includes('--stop')) {
      const address = new URL(session.url), secret = address.hash.slice('#token='.length);
      const response = await fetch(address.origin + '/api/quit', { method: 'POST', headers: {
        Origin: address.origin, Cookie: `writ=${secret}`, 'Content-Type': 'application/json' }, body: '{}' });
      if (!response.ok) throw Error('The running Writ app could not be stopped.');
      for (let attempt = 0; attempt < 300; attempt++) {
        try { await readFile(sessionPath); } catch (error) { if (error.code === 'ENOENT') process.exit(0); throw error; }
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      throw Error('Writ is still finishing a storage operation. Retry after it completes.');
    }
    if (!args.includes('--no-open')) await openNative(session.url);
    process.exit(0);
  }
  await unlink(sessionPath);
} catch (error) { if (error.code !== 'ENOENT') throw error; }
if (args.includes('--stop')) process.exit(0);
const lock = await open(sessionPath, 'wx', 0o600);
const token = randomBytes(32).toString('hex');
let broker;
try { broker = await new Broker(policy, sync, data, folder).initialize(); }
catch (error) { await lock.close(); await unlink(sessionPath); throw error; }
let origin, closing = false;
function typed(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw Error('Invalid request.');
  for (const name of ['id', 'connection', 'version', 'source', 'expected', 'extra', 'clearance']) {
    if (name in input && (!Number.isInteger(input[name]) || input[name] < 0 || input[name] > 0xffffffff)) throw Error('Invalid request number.');
  }
  for (const name of ['name', 'path', 'kind', 'key', 'etag', 'endpoint', 'bucket', 'region', 'prefix', 'accessKey', 'secretKey', 'sessionToken', 'continuation']) {
    if (name in input && (typeof input[name] !== 'string' || input[name].length > 8192)) throw Error('Invalid request text.');
  }
  for (const name of ['enabled', 'paused', 'open', 'recovery']) if (name in input && typeof input[name] !== 'boolean') throw Error('Invalid request flag.');
  return input;
}
function matches(value) {
  return typeof value === 'string' && value.length === token.length && timingSafeEqual(Buffer.from(value), Buffer.from(token));
}
async function body(request, maximum) {
  let count = 0; const chunks = [];
  for await (const chunk of request) { count += chunk.length; if (count > maximum) throw Error('Request size limit reached.'); chunks.push(chunk); }
  return Buffer.concat(chunks);
}
const server = createServer(async (request, response) => {
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('Content-Security-Policy', "default-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
  const json = (status, value) => { response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' }); response.end(JSON.stringify(value)); };
  try {
    if (request.headers.host !== new URL(origin).host) return json(403, { error: 'Unknown app host.' });
    const url = new URL(request.url, origin);
    if (request.method === 'POST' && request.headers.origin !== origin) return json(403, { error: 'Open this request in the local Writ app.' });
    if (request.method === 'POST' && url.pathname === '/api/session') {
      const input = JSON.parse((await body(request, 1024)).toString());
      if (!matches(input.token)) return json(403, { error: 'Launch Writ again to open a new session.' });
      response.setHeader('Set-Cookie', `writ=${token}; HttpOnly; SameSite=Strict; Path=/`);
      return json(200, { ok: true });
    }
    if (request.method === 'GET' && ['/', '/app.js', '/style.css'].includes(url.pathname)) {
      const name = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
      response.writeHead(200, { 'Content-Type': { 'index.html': 'text/html; charset=utf-8', 'app.js': 'text/javascript; charset=utf-8', 'style.css': 'text/css; charset=utf-8' }[name] });
      return response.end(await readFile(join(here, 'ui', name)));
    }
    const cookie = /(?:^|;\s*)writ=([^;]+)/.exec(request.headers.cookie || '')?.[1];
    if (!matches(cookie)) return json(401, { error: 'Launch Writ to open its private control session.' });
    if (request.method === 'GET' && url.pathname === '/api/status') return json(200, broker.status());
    if (request.method === 'GET' && url.pathname === '/api/provenance') return json(200, { origins: policy.provenance(broker.state, typed({ version: Number(url.searchParams.get('version')) }).version) });
    if (request.method !== 'POST') return json(404, { error: 'Unknown app action.' });
    if (url.pathname === '/api/upload') {
      const input = typed(JSON.parse(request.headers['x-writ-file'] || '{}'));
      const bytes = await body(request, 67108864);
      const result = await broker.exclusive(() => broker.transfer({ ...input, source: 0, kind: 'save' }, bytes));
      return json(200, result);
    }
    const input = typed(JSON.parse((await body(request, 32768)).toString()));
    const result = await broker.exclusive(async () => {
      switch (url.pathname) {
        case '/api/connect': return broker.connect(input);
        case '/api/configure': return broker.configure(input.id, input.clearance, input.enabled);
        case '/api/transfer': return broker.transfer(input);
        case '/api/keep': return broker.keep(input.version, input.open === true);
        case '/api/history': return broker.historyCopy(input.version, true);
        case '/api/refresh': await broker.refresh(); return broker.syncWorking();
        case '/api/retry': return broker.finishPending();
        case '/api/pause': broker.paused = input.paused === true; return;
        case '/api/open-folder': return openNative(input.recovery ? join(data, 'Recovery') : folder);
        case '/api/list-existing': return broker.listExisting(input.connection, input.prefix || '', input.continuation || '');
        case '/api/import': return broker.importExisting(input);
        case '/api/examples':
          for (const line of policy.samples().trimEnd().split('\n')) {
            const [path, extra, bytes] = line.split('\t');
            await broker.transfer({ connection: input.connection, path, source: 0, expected: 0, extra: Number(extra), kind: 'save' }, Buffer.from(bytes, 'hex'));
          }
          return;
        case '/api/quit': setTimeout(stop, 100); return;
        default: throw Error('Unknown app action.');
      }
    });
    json(200, result ?? { ok: true });
  } catch (error) { json(400, { error: safeMessage(error), code: error.code || '' }); }
});
server.headersTimeout = 10000; server.requestTimeout = 120000; server.maxConnections = 16;
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
origin = `http://127.0.0.1:${server.address().port}`;
const url = `${origin}/#token=${token}`;
await lock.writeFile(JSON.stringify({ pid: process.pid, url })); await lock.sync(); await lock.close();
process.stdout.write('Writ Drive is running. Open the app from its launcher.\n');
if (!args.includes('--no-open')) await openNative(url);
let scanning = false;
const timer = setInterval(async () => {
  if (scanning || closing) return;
  scanning = true;
  try { await broker.exclusive(() => broker.syncWorking()); }
  catch (error) { broker.problem = safeMessage(error); }
  finally { scanning = false; }
}, 5000);
async function stop() {
  if (closing) return; closing = true; clearInterval(timer);
  server.close(); await broker.queue;
  await unlink(sessionPath).catch(() => {});
}
process.on('SIGINT', stop); process.on('SIGTERM', stop);
