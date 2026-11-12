// Native browser/control-channel probe. Credentials stay in local variables;
// screenshots are captured only after the connection form has been cleared.
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomBytes } from 'node:crypto';
const [playwrightPath, data, connectionFile, evidence] = process.argv.slice(2);
const { chromium } = await import(pathToFileURL(playwrightPath));
const session = JSON.parse(await readFile(join(data, 'session.json')));
const config = JSON.parse(await readFile(connectionFile));
const browser = await chromium.launch({ headless: true, channel: process.env.WRIT_BROWSER_CHANNEL || undefined });
const page = await browser.newPage({ viewport: { width: 1440, height: 1050 } });
const errors = []; page.on('pageerror', error => errors.push(error.message));
const checks = [];
function check(name, condition = true) { assert(condition, name); checks.push(name); console.log('PASS ' + name); }
try {
  await page.goto(session.url); await page.locator('#first-connect').waitFor({ state: 'visible' });
  await page.screenshot({ path: join(evidence, 'welcome.png'), fullPage: true });
  const prefix = config.prefix + '/browser-' + randomBytes(10).toString('hex');
  async function connect(name, suffix, clearance, first = false) {
    await page.locator(first ? '#first-connect' : '#connect').click();
    for (const [field, value] of Object.entries({ ...config, name, prefix: prefix + '/' + suffix })) {
      const control = page.locator(`#connection-form [name="${field}"]`);
      if (await control.count()) await control.fill(value);
    }
    await page.locator('#connection-form [name=clearance]').selectOption(String(clearance));
    await page.locator('#connection-form [type=submit]').click();
    await page.locator('#connection-dialog').waitFor({ state: 'hidden', timeout: 60000 });
  }
  await connect('Private workspace', 'private', 3, true);
  await connect('Public destination', 'public', 0);
  check('connection form verifies two real storage destinations');
  await page.locator('[data-connection="1"]').click(); await page.locator('#examples').click();
  await page.locator('#files tr').filter({ hasText: 'project-notes.txt' }).waitFor({ state: 'visible', timeout: 60000 });
  await page.locator('#files tr').filter({ hasText: 'project-notes.txt' }).click();
  await page.locator('#copy').click(); await page.locator('#copy-destination').selectOption('2');
  await page.locator('#copy-form [type=submit]').click();
  await page.waitForFunction(() => document.querySelector('#copy-form .form-error').textContent.includes('No file contents were uploaded'));
  check('actual copy control displays a pre-upload policy denial');
  await page.screenshot({ path: join(evidence, 'denied-copy.png'), fullPage: true });
  await page.locator('#copy-dialog [data-close]').click();
  await page.locator('#copy').click(); await page.locator('#copy-destination').selectOption('1');
  await page.locator('#copy-form [type=submit]').click();
  await page.locator('#copy-dialog').waitFor({ state: 'hidden', timeout: 60000 });
  check('same copy control persists an approved destination copy');
  await page.locator('#keep-local').click();
  await page.waitForFunction(() => document.querySelector('#notice').textContent.includes('available in your working folder'));
  const status = await page.evaluate(() => fetch('/api/status').then(r => r.json()));
  const initial = status.files.find(f => f.path === 'Examples/project-notes.txt');
  const local = join(status.folder, '1', 'Examples', 'project-notes.txt');
  await writeFile(local, 'Edited through an ordinary filesystem file.\n');
  await page.waitForFunction(async initial => {
    const s = await fetch('/api/status').then(r => r.json());
    return s.files.some(f => f.id === initial.id && f.version > initial.version);
  }, initial, { timeout: 60000 });
  check('background watcher observes a real desktop file edit and publishes it');
  await page.locator('#refresh').click();
  await page.locator(`[data-restore="${initial.version}"]`).waitFor({ state: 'visible', timeout: 30000 });
  await page.locator('#tighten').selectOption('2'); await page.locator('#apply-rule').click();
  await page.waitForFunction(() => document.querySelector('#notice').textContent.includes('Restriction added'));
  await page.locator(`[data-restore="${initial.version}"]`).click();
  await page.waitForFunction(() => document.querySelector('#notice').textContent.includes('Historical bytes restored'));
  check('history control restores actual old bytes without dropping newer restrictions', await page.locator('#inspector .badge').first().textContent() === 'Private + region');
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: join(evidence, 'files-and-provenance.png'), fullPage: true });
  await page.locator('#activity-tab').click();
  check('activity records both denied and verified operations', (await page.locator('#activity').textContent()).includes('denied') && (await page.locator('#activity').textContent()).includes('synced'));
  await page.screenshot({ path: join(evidence, 'activity.png'), fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({ path: join(evidence, 'mobile.png'), fullPage: true });
  check('narrow window has no horizontal page overflow', await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  const origin = new URL(session.url).origin;
  check('unauthenticated API calls are refused', (await fetch(origin + '/api/status')).status === 401);
  const token = new URL(session.url).hash.split('=')[1];
  check('cross-origin mutations are refused', (await fetch(origin + '/api/pause', { method: 'POST', headers: { origin: 'https://foreign.example', cookie: `writ=${token}`, 'Content-Type': 'application/json' }, body: '{"paused":true}' })).status === 403);
  const visible = await page.evaluate(() => fetch('/api/status').then(r => r.text()));
  check('control API does not expose storage credentials', !visible.includes(config.secretKey) && !visible.includes(config.accessKey));
  check('no browser runtime errors', errors.length === 0);
  await writeFile(join(evidence, 'browser-check.json'), JSON.stringify({ browser: await browser.version(), checks, errors }, null, 2));
} catch (error) {
  let message = error.stack || String(error);
  // Browser call logs may include the launch URL on navigation failure.
  // Neither that local bearer nor any storage credential belongs in evidence.
  for (const secret of [session.url, new URL(session.url).hash.slice('#token='.length),
    config.accessKey, config.secretKey, config.sessionToken].filter(Boolean))
    message = message.replaceAll(secret, '[redacted]');
  process.stderr.write(message + '\n'); process.exitCode = 1;
} finally { await browser.close(); }
