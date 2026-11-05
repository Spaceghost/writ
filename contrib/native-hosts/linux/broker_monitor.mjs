#!/usr/bin/env node
// Mechanical private-pipe transport for the Linux broker monitor
// (hosts/linux/monitor/LinuxHost.bend built to an ES module). The generated
// Bend module owns all decoding, state, and decisions: this harness turns one
// lowercase-hex request line into the frame's byte values, calls `serve`,
// retains `next` before replying, and writes `<sequence> TAB <reply>`. It
// never reads a field of the frame or the reply beyond checking the reply's
// shape. A worker must never inherit these pipe ends or this process.
import { pathToFileURL } from 'node:url';
import { isAbsolute } from 'node:path';

const MAX_LINE = 1024;        // 2 x LinuxHost.max_frame_bytes()
const MAX_REPLY = 480;
const MAX_REQUESTS = 100000;
const REPLY = /^LINUXMON1\t[A-Z]{1,15}\t[A-Za-z0-9=:_-]{1,63}\trev=[0-9]+;[0-9A-Z:,+-]{1,240}\n$/;

function stopped() {
  process.stderr.write('Writ Linux monitor transport stopped.\n');
  process.exitCode = 2;
  process.stdin.destroy();
}

function bytesOf(line) {
  if (line.length % 2 !== 0 || !/^[0-9a-f]*$/.test(line)) throw Error();
  let list = { $: 'Nil' };
  for (let i = line.length - 2; i >= 0; i -= 2) {
    list = { $: 'Con', head: parseInt(line.slice(i, i + 2), 16), tail: list };
  }
  return list;
}

async function run() {
  if (process.argv.length !== 3 || !isAbsolute(process.argv[2])) throw Error();
  const { default: monitor } = await import(pathToFileURL(process.argv[2]).href);
  for (const name of ['initial', 'serve', 'next', 'reply']) {
    if (typeof monitor[name] !== 'function') throw Error();
  }
  let state = monitor.initial();
  let sequence = 0;
  let line = '';
  for await (const chunk of process.stdin) {
    for (const byte of chunk) {
      if (byte !== 10) {
        if (line.length === MAX_LINE) throw Error();
        line += String.fromCharCode(byte);
        continue;
      }
      if (sequence === MAX_REQUESTS) throw Error();
      sequence += 1;
      // The monitor's clock is this monotone request sequence.
      const served = monitor.serve(state, bytesOf(line), sequence);
      state = monitor.next(served);
      const reply = monitor.reply(served);
      line = '';
      if (typeof reply !== 'string' || reply.length > MAX_REPLY || !REPLY.test(reply)) throw Error();
      await new Promise((resolve, reject) => {
        process.stdout.write(`${sequence}\t${reply}`, error => error ? reject(error) : resolve());
      });
    }
  }
  if (line.length !== 0) throw Error();
}

process.stdout.on('error', stopped);
run().catch(stopped);
