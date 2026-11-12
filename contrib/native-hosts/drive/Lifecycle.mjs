// Native package probe. Uses only a fresh account/data home supplied by CI.
import assert from 'node:assert/strict';
import { readFile, writeFile, access } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { spawn } from 'node:child_process';
const [packagePath, action] = process.argv.slice(2);
assert(packagePath && ['start', 'stopped'].includes(action), 'Pass package path and start/stopped.');
const data = join(process.env.LOCALAPPDATA || process.env.XDG_DATA_HOME || join(homedir(), '.local', 'share'), 'WritDrive');
const folder = join(homedir(), 'Writ Drive');
const sessionPath = join(data, 'session.json');
const retained = join(folder, 'uninstall-preservation.txt');
const bytes = 'Ordinary local work must survive application removal.\n';
async function exists(path) { try { await access(path); return true; } catch (error) { if (error.code === 'ENOENT') return false; throw error; } }
if (action === 'start') {
  assert(!await exists(data) && !await exists(folder), 'Lifecycle probe requires unused default drive paths.');
  const windows = process.platform === 'win32';
  const child = spawn(join(resolve(packagePath), windows ? 'WritDrive.exe' : 'writ-linux'), windows ? ['--no-open'] : ['app', '--no-open'], { stdio: 'ignore', windowsHide: true });
  child.on('error', error => { throw error; }); child.unref();
  let session;
  for (let attempt = 0; attempt < 300; attempt++) {
    try { session = JSON.parse(await readFile(sessionPath, 'utf8')); if (session.url) break; }
    catch (error) { if (error.code !== 'ENOENT' && !(error instanceof SyntaxError)) throw error; }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert(session?.url, 'Packaged app starts within 30 seconds.');
  const url = new URL(session.url);
  const response = await fetch(url.origin + '/api/status', {headers:{Cookie:'writ=' + url.hash.slice('#token='.length)}});
  assert.equal(response.status, 200);
  const status = await response.json(); assert.deepEqual(status.connections, []);
  const html = await (await fetch(url.origin)).text(); assert(html.includes('Connect storage'));
  await writeFile(retained, bytes, { flag: 'wx' });
  console.log('PASS packaged native launcher opens the local app with an empty connection state');
} else {
  assert(!await exists(sessionPath), 'Uninstaller waits for the app session to close.');
  assert.equal(await readFile(retained, 'utf8'), bytes);
  console.log('PASS uninstaller stops the app and retains ordinary working files');
}
