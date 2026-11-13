// Explicitly malformed LINUXSUP1 test peer for supervisor-owner-test.c only:
// loaded by runtime/supervisor-policy.mjs in place of the generated owner. It
// holds no policy. Its reply to a CONTROL frame depends on the role field:
//   role 1: SERVED (an outcome that does not belong to CONTROL)
//   role 2: REVOKE_REFUSED carrying S1 (a control reply with an effect)
//   role 3: ERROR (the interpreter's own failure)
// to DRAIN: REVOKE_APPLIED (not a drain outcome); and to PROVISION:
// PROVISIONED, whatever the record, so the malformed replies above are reached.
const replies = { '1': 'SERVED\t0\t-', '2': 'REVOKE_REFUSED\t0\tS1', '3': 'ERROR\t1\t-' };
export default {
  initial: () => 0,
  dispatch: (sequence, frame) => {
    const field = frame.split('\t');
    const body = field[1] === 'PROVISION' ? 'PROVISIONED\t0\t-'
      : field[1] === 'DRAIN' ? 'REVOKE_APPLIED\t1\t-' : (replies[field[3]] ?? 'ERROR\t1\t-');
    return [sequence + 1, `LINUXSUP1\t${sequence + 1}\t${body}\n`];
  },
  next: step => step[0],
  reply: step => step[1],
};
