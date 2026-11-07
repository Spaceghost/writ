// Fixed-command public log capture; timeouts and cleanup are managed externally.
import path from 'node:path';
import { spawn } from 'node:child_process';
import { captureToFiles } from './ci-capture-core.mjs';

if (process.argv.length !== 4) process.exit(2);
const [build, evidence] = process.argv.slice(2);
if (!path.isAbsolute(build) || !path.isAbsolute(evidence)) process.exit(2);
// Only this fixed command is permitted. The path is passed as $1, not evaluated.
const child = spawn('/bin/bash', ['-c', 'exec /usr/bin/make -C "$1" run/writ_bend_monitor_nested_accept 2>&1', 'writ-ci', build],
  { stdio: ['ignore', 'pipe', 'inherit'] });
const exit = new Promise((resolve, reject) => {
  child.once('error', reject);
  child.once('exit', (code, signal) => resolve({ code, signal }));
});
const ok = await captureToFiles(child.stdout, exit, path.join(evidence, 'run.log.gz.partial'),
  path.join(evidence, 'run.log.gz'), path.join(evidence, 'run-meta.json'));
if (!ok) {
  console.error('INCOMPLETE: capture failed; child cleanup unverified');
  // Do not wait indefinitely for a writer that ignores the closed pipe.
  // This does not signal a PID or establish that the child is gone.
  process.exit(1);
}
