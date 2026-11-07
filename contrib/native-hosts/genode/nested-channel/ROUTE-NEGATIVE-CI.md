# Experimental public nested-init route refusal

A public synthetic R client asks its nested Genode `init` for the fixed
`Writ_channel` named `channel`. The paired positive retains the existing route.
The proposed negative removes the one nested-client `Writ_channel -> parent`
route, while keeping the monitor policy, parent route, quotas, client and public
inputs. The pinned Genode source predicts that nested init reports no route and
the client reports its parent denied the session. A prior [incomplete run](../../../../verification/genode-route-negative-42357627656/README.md)
captured those public messages, but its harness timed out and the paired
positive did not boot. This follow-up is an unrun candidate.

The earlier [observed nested public pair](../../../../verification/genode-nested-ci-7b31cfc/README.md)
used an expected-decision mismatch: its negative still committed through the
monitor. It did not exercise route refusal. This new control does not establish
confinement, a Bend denial, actor authentication, delegation, or host
qualification. The root boot helper retains a broad default route and the test
is public-only. Missing messages, a setup error, quota issue, unexpected
configuration or timeout produce incomplete evidence, not a refusal result.

## Scope and source identity

The experimental workflow is guarded to manual dispatch on
`Spaceghost/writ` ref `lane/genode-route-negative-ci`; all three job guards
include the same repository, event and ref. Other invocations retain the existing
base-hw job. Both nested jobs use separate fresh GitHub-hosted VMs and check out
exact fixture source `e129c931ceb1d249cf0b0874a91390e5eef840c9`; the tooling
checkout must match the actual workflow SHA. GitHub's branch ref is mutable:
independent exact-source review, verification of the remote ref immediately
before any separately authorized dispatch, and trusted no-concurrent-writer
control remain prerequisites. Metadata after dispatch cannot close that race.
The code in this branch is **not** authorization to dispatch.

`ci-route-fixture.py` leaves the positive fixture verbatim and constructs the
negative from that same fixed source by deleting exactly one nested route and
replacing the terminal harness assertions. It refuses unexpected source shapes.
The negative requires the monitor's synthetic-authority and service logs, the
nested init's exact child/service/label no-route message, and the client's denied
session message. It waits boundedly for the client message: the existing client
may sleep after refusal, so exit or timeout alone cannot establish the result.
The pinned Genode logger frames warnings with `ESC [34m` and errors with
`ESC [31m`; both fixture and raw-log auditor require those exact prefixes. The
warning also requires the terminating `ESC [0m`. The Expect patterns contain
actual ESC bytes, rather than a braced octal escape; the terminal client wait
may end before its reset. After that wait the fixture checks accumulated output
and uses the same spawn to wait for any still-missing required marker, including
the warning and both monitor markers. A 122-second total marker deadline,
rounded up by at most one second on an individual wait, and the existing outer
timeout bound this attempt. Capture and hashing retain original bytes without
color removal. Any missing marker or timeout remains incomplete. The monitor's no-policy refusal is
a separate condition and cannot substitute for the init route marker.

The driver retains original and actual `.run` files, their hashes and the diff.
It compares the installed scenario configuration byte-for-byte against the
1,710-byte `installed-config.txt` member in the historical positive ZIP, or
against that exact member with the one nested route line removed. It verifies
the member's fixed recorded SHA-256 and ZIP CRC and imposes a 64 KiB read cap;
it does not extract archive paths. The separately readable historical config
copy had a terminal newline normalized and is not used as an exact reference.
The archive belongs to the fixed source checkout, whose source manifest is
checked before and after the run. These checks are observations, not process
attestation against a same-UID adversary.

## Native tooling, trust, and limits

The branch-specific harness reuses the reviewed public-only collector from
`7b31cfc3ea750ed25f9091e8723449cf89ea15f9`: `ci-disposable.sh` provides the
fixed-source external build and pinned input checks, `ci-route-fixture.py`
prepares and compares the fixed test configuration, `ci-log-capture.sh`,
`ci-log-collect.mjs`, `ci-capture-core.mjs` and `ci-gzip.mjs` bound and preserve
the full build stream, `ci-log-audit.mjs` audits bytes and public markers, and
`ci-snapshot.mjs` prepares explicitly allowlisted evidence. The `ci-*-probe`
files exercise only native harness behavior using local synthetic data and
owned temporary subprocesses. None adds a Writ policy or alternate release
path. Raw and compressed byte caps, integrity checks and incomplete failure
records remain in force; build output disk use itself is not quota-proven.

The source archive's [prior public run](../../../../verification/genode-route-negative-42357627656/README.md)
hit three download timeouts. `ci-fetch-libc.sh` makes at most one 600-second
HTTPS attempt to the fixed FreeBSD archive URL, then at most one to the fixed
`ftpmirror.your.org` URL. HTTPS redirects and normal certificate validation
remain required; curl's user configuration is disabled. This mirror is a
candidate source, not a claim of official status or runner reliability. Each
attempt has a separate private partial file and curl-only file-size cap; the
archive is admitted only at exactly 159,564,768 bytes and the original pinned
SHA-256 `0da393ac2174168a71c1c527d1453e07372295187d05c288250800cb152a889b`.
The `libc-fetch.txt` record includes attempted URL, transfer status, observed
size/hash and selected source when available; the download wrapper has a
21-minute total timeout. A forced cancellation can prevent final metadata or
leave a partial file; that is incomplete, not an admitted input or a cleanup
claim. The snapshot and explicit upload list include this metadata. Same-UID
interference and redirect trust remain within the stated VM assumptions.

The runner has platform/action credentials even with minimum `contents: read`
and checkout credential persistence disabled. No credentials are deliberately
passed to the fixture. The VM, GitHub actions, public build sources, runner and
same-UID processes remain trusted; unfiltered output and upload-time same-UID
races cannot guarantee against accidental disclosure. Output capture and upload
are bounded attempts, not delivery guarantees. Hard cancellation or a timeout
can prevent preservation. These jobs deliberately conclude nonzero and
`overall=incomplete` even when fixture assertions match because in-guest
process cleanup is unverified. Disposal of the VM is fallback containment,
not evidence of verified cleanup; no unrelated process or VM is signalled.
No shared-host Genode, QEMU or withheld Linux identity probe is authorized.

## Portable verification

Before exact independent review, run the `ci-route-probe.py`,
`ci-expect-probe.py`, `ci-fetch-libc-probe.py`, `ci-gzip-probe.mjs`,
`ci-snapshot-probe.mjs`, and `ci-capture-probe.sh` controls, ShellCheck, strict
OpenSpec and the source-manifest check. The route probe exercises the actual
Tcl assertion against matching synthetic text, omitted/wrong child or label,
missing monitor/client, and server-policy-only text; it checks the source and
config differences and rejects the normalized historical copy. It also checks
expected, absent and incorrect ANSI colors, warning reset and client origin.
The Expect/PTY probe exercises all 24 synthetic marker arrival orders, split
writes, missing/wrong markers and a real timeout. The offline mock-curl probe
tests a primary success, fallback after transfer/size/hash failure, total
failure and existing-target refusal; it makes no network request. The gzip probe
requires each scenario marker and expected producer status. These controls do
not boot Genode or validate the predicted native log ordering. Independent review
of this exact fixture, workflow, provenance and all failure paths is still
required before an experiment.

The [local offline control record](../../../../verification/genode-route-followup-offline/README.md) identifies the tested harness sources and limits; it is not a Genode result.
