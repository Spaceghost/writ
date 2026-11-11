# Windows network probe evidence

Branch: `lane/windows-network-evidence`, based on `0bc0c25`.

## Concrete gap

The strict public-canary worker currently reports one `WSAStartup` failure as
four network errors. The report does not identify which network operation was
attempted. In addition, the TCP helper's shared final `WSAEACCES` check can credit
an error from `select` or the `getsockopt` query itself as a denied connection.
Those APIs observe readiness/status; a failed query is not a connection result.
This is a source-level weakness in evidence classification, not an observed
Windows escape or a claim that those unusual API errors occurred in CI.

## Scope

- Keep policy, worker launch restrictions, capabilities, WFP, admission order,
  destinations and public fixture unchanged. This is the existing native probe
  exception under NM007/NM008, not a new host profile or pre-admission protocol.
- Extract the fixed four-endpoint Winsock probe into a small native module.
  Report startup status once and a terminal API stage for each endpoint. Bump
  the fixed local report version so mixed probe/broker builds fail closed.
- Credit `WSAEACCES` only from socket creation, direct connect, a successfully
  retrieved connection `SO_ERROR`, or UDP send. Initialization, nonblocking
  setup, wait/query failure and timeout remain incomplete and fail the check.
- Use controlled WinSock call failures to test the actual native probe code,
  and ordinary native Windows IPv4/IPv6 TCP/UDP loopback receivers as positive
  controls. Neither test supplies LPAC qualification. Run the unchanged strict
  fixture and preserve its actual result; setup failure must still fail.
- The active `windows/files-on-demand` lane has no changes in the probe files
  touched here. Use an isolated worktree and leave that checkout alone.

## Tasks and acceptance

1. Implement bounded stage-specific reporting and failure classification;
   inspect Microsoft API contracts and obtain independent review.
2. Run synthetic failure-path tests and real loopback controls on Windows;
   build/run the full WinFsp fixture for integration and actual strict-worker
   observations. Run applicable unchanged Bend checks and ordinary proofs.
3. Preserve logs, source/run/artifact hashes and negative outcomes. Update the
   native inventory, verification and NM008 traceability; validate OpenSpec
   1.16.0, review independently, refresh the source manifest and push master
   normally under the user's existing authorization.

The Genode master rerun passed native execution but failed GitHub artifact
creation. It has been retried separately; no native deadline/runtime change is
needed for that service failure.

## API references

- [WSAStartup](https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-wsastartup): its return value is the initialization result; later socket calls require success.
- [select](https://learn.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-select): return/error describes readiness inspection, including timeout.
- [getsockopt](https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-getsockopt): the API return indicates query success; `SO_ERROR` is a separate returned value and length.
