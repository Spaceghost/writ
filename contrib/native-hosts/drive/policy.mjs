// Mechanical codec and invocation only. Bend owns catalogs, parent policies,
// current versions, pending intents, and all admission/confirmation decisions.
export class DecisionError extends Error {
  constructor(code) { super(code); this.code = code; }
}
export function requireChange(policy, change) {
  const code = policy.status(change);
  if (code !== 'OK') throw new DecisionError(code);
  return policy.next(change);
}
function number(value) {
  if (!/^(0|[1-9][0-9]{0,9})$/.test(value) || Number(value) > 0xffffffff) throw Error('Invalid catalog number.');
  return Number(value);
}
function unhex(value) {
  if (!/^(?:[0-9a-f]{2}){1,512}$/.test(value)) throw Error('Invalid catalog text.');
  return Buffer.from(value, 'hex').toString('ascii');
}
export function rows(text) {
  if (typeof text !== 'string' || Buffer.byteLength(text) > 1048576 || /[^\x09\x0a\x20-\x7e]/.test(text)) throw Error('Invalid catalog encoding.');
  const lines = text.split('\n');
  if (lines.shift() !== 'WRITDRIVE1' || lines.pop() !== '' || lines.length > 529) throw Error('Invalid catalog framing.');
  const connections = [], files = []; let pending = null;
  for (const line of lines) {
    const f = line.split('\t');
    if (f[0] === 'C' && f.length === 6 && !files.length && !pending && /^[01]$/.test(f[5])) {
      connections.push({ id: number(f[1]), name: unhex(f[2]), binding: f[3], clearance: number(f[4]), enabled: f[5] === '1' });
    } else if (['F', 'P'].includes(f[0]) && f.length === 12 && !pending) {
      const record = { id: number(f[1]), version: number(f[2]), connection: number(f[3]), path: unhex(f[4]),
        size: number(f[5]), digest: f[6], source: number(f[7]), previous: number(f[8]), extra: number(f[9]), kind: f[10], restrictions: number(f[11]) };
      if (f[0] === 'P') pending = record; else files.push(record);
    } else throw Error('Invalid catalog record.');
  }
  return { connections, files, pending };
}
export function load(policy, text) {
  const parsed = rows(text); let state = policy.empty();
  for (const c of parsed.connections) state = requireChange(policy, policy.configure(state, c.id, c.name, c.binding, c.clearance, c.enabled));
  for (const f of parsed.files) state = requireChange(policy, policy.load_file(state, f.connection, f.path, f.size, f.digest, f.source, f.previous, f.extra, f.kind, f.id, f.version));
  if (parsed.pending) {
    const f = parsed.pending;
    state = requireChange(policy, policy.reserve(state, f.connection, f.path, f.size, f.digest, f.source, f.previous, f.extra, f.kind));
  }
  // Includes canonical order, no duplicate connections, exact generated IDs,
  // and independently reconstructed inherited restriction masks.
  if (policy.dump(state) !== text) throw Error('Noncanonical or inconsistent catalog.');
  return state;
}

export function streamDigest(sync, bytes) {
  let state = sync.initial();
  const call = (op, a = 0, b = 0, c = 0, body = '-') => {
    const result = sync.dispatch(state, `WRITFS1\t${op}\t${a}\t${b}\t${c}\t0\t${body}`);
    state = sync.next(result);
    const fields = sync.reply(result).trimEnd().split('\t');
    if (fields[2] !== 'OK') throw new DecisionError(fields[4]);
    return fields[4];
  };
  call('OPEN', 0, 0, 0, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  call('LOCAL', 1, 0, bytes.length);
  for (let offset = 0; offset < bytes.length; offset += 65536) call('CHUNK', offset, 0, 0, bytes.subarray(offset, offset + 65536).toString('hex'));
  return call('LOCAL_END');
}
