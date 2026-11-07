// Fixed capture lifecycle I/O, with injected streams only for offline probes.
import fs from 'node:fs';
import { compressRaw, auditGzip, RAW_CAP, COMPRESSED_CAP } from './ci-gzip.mjs';

function publish(path, value) {
  const tmp = `${path}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(value, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
  fs.renameSync(tmp, path);
}

export async function captureToFiles(input, childExit, partial, completed, metaPath,
  rawCap = RAW_CAP, compressedCap = COMPRESSED_CAP) {
  let metadata = { capture: 'incomplete', raw_cap: rawCap, compressed_cap: compressedCap };
  // Handle an early spawn error even while gzip is still draining.
  const handledExit = childExit.then(value => ({ value }), error => ({ error }));
  try {
    const capture = await compressRaw(input, partial, rawCap, compressedCap);
    metadata = { ...metadata, ...capture, capture: 'incomplete' };
    // Persist before waiting for a child which may ignore the closed pipe.
    if (!capture.complete) {
      metadata.reason = `incomplete gzip capture: ${capture.reason}`;
      metadata.child_status = 'not_waited_after_capture_failure';
      publish(metaPath, metadata);
      return false;
    }
    metadata.child_status = 'waiting_after_drain';
    publish(metaPath, metadata);
    const outcome = await handledExit;
    if (outcome.error) throw outcome.error;
    const verified = await auditGzip(partial, capture, [], rawCap, compressedCap);
    fs.linkSync(partial, completed); // refuse to replace an existing output
    fs.unlinkSync(partial);
    metadata = { ...metadata, child: outcome.value, audit: verified, capture: 'complete' };
    delete metadata.child_status;
    publish(metaPath, metadata);
    return true;
  } catch (error) {
    metadata = { ...metadata, capture: 'incomplete', reason: String(error.message) };
    try { publish(metaPath, metadata); }
    catch (writeError) { console.error('INCOMPLETE: cannot finalize capture metadata:', writeError.message); }
    return false;
  }
}
