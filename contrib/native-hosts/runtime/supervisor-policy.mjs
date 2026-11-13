#!/usr/bin/env node
// Mechanical private-pipe transport for LINUXSUP1 (hosts/linux/monitor/
// SupervisorWire.bend). Same contract as node-policy.mjs: the generated Bend
// module owns all policy and state; this file frames bytes and checks reply
// shape only. Only the native supervisor driver may hold these pipe ends.
import { pathToFileURL } from 'node:url';
import { isAbsolute } from 'node:path';

const MAX_FRAME = 8300;
const MAX_REPLY = 256;
const MAX_REQUESTS = 100000;
const REPLY = /^LINUXSUP1\t([1-9][0-9]{0,5})\t([A-Z_]{1,32})\t([01])\t(-|[SRDC](?:0|[1-9][0-9]*)(?:,[SRDC](?:0|[1-9][0-9]*))*)\n$/;

function stopped() {
  process.stderr.write('Writ supervisor transport stopped.\n');
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
      const parsed = REPLY.exec(reply);
      if (!parsed || Number(parsed[1]) !== sequence) throw Error();
      await new Promise((resolve, reject) => {
        process.stdout.write(reply, error => error ? reject(error) : resolve());
      });
    }
  }
  if (length !== 0) throw Error();
}

process.stdout.on('error', stopped);
run().catch(stopped);
