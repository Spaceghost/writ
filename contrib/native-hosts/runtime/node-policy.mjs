#!/usr/bin/env node
// Mechanical private-pipe transport. The generated Bend module owns all policy
// and state. A worker must never inherit these pipe ends or this process handle.
import { pathToFileURL } from 'node:url';
import { isAbsolute } from 'node:path';

const MAX_FRAME = 131200;
const MAX_REPLY = 256;
const MAX_REQUESTS = 100000;

function stopped() {
  process.stderr.write('Writ policy transport stopped.\n');
  process.exitCode = 2;
  process.stdin.destroy();
}

async function run() {
  if (process.argv.length !== 3 || !isAbsolute(process.argv[2])) throw Error();
  const { default: policy } = await import(pathToFileURL(process.argv[2]).href);
  for (const name of ['initial', 'dispatch', 'next', 'reply']) {
    if (typeof policy[name] !== 'function') throw Error();
  }
  let state = policy.initial();
  let sequence = 0;
  let length = 0;
  const frame = Buffer.alloc(MAX_FRAME);
  for await (const chunk of process.stdin) {
    for (const byte of chunk) {
      if (byte !== 10) {
        if (length === MAX_FRAME || (byte !== 9 && (byte < 32 || byte > 126))) throw Error();
        frame[length++] = byte;
        continue;
      }
      if (sequence === MAX_REQUESTS) throw Error();
      const step = policy.dispatch(state, frame.toString('ascii', 0, length));
      state = policy.next(step);
      const reply = policy.reply(step);
      length = 0;
      sequence += 1;
      if (typeof reply !== 'string' || Buffer.byteLength(reply, 'ascii') > MAX_REPLY) throw Error();
      const parsed = /^WRITFS1\t([1-9][0-9]{0,5})\t(OK|DENY|ERROR)\t(0|[1-9][0-9]{0,9})\t([A-Z_]+|[0-9a-f]{64})\n$/.exec(reply);
      if (!parsed || Number(parsed[1]) !== sequence || Number(parsed[3]) > 4294967295) throw Error();
      await new Promise((resolve, reject) => {
        process.stdout.write(reply, error => error ? reject(error) : resolve());
      });
    }
  }
  if (length !== 0) throw Error();
}

process.stdout.on('error', stopped);
run().catch(stopped);
