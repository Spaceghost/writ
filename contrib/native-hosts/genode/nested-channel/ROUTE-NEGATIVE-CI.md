# Experimental public nested-init route refusal

A public synthetic R client asks its nested Genode `init` for the fixed
`Writ_channel` named `channel`. The paired positive retains the existing route.
The proposed negative removes the one nested-client `Writ_channel -> parent`
route, while keeping the monitor policy, parent route, quotas, client and public
inputs. The pinned Genode source predicts that nested init reports no route and
the client reports its parent denied the session. This is a **proposed** control;
no route-negative native observation has been made by these files.

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
If startup ordering prevents these markers from all appearing within the
captured prefix, the outcome is incomplete. The monitor's no-policy refusal is
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

Before exact independent review, run the `ci-route-probe.py`, `ci-gzip-probe.mjs`,
`ci-snapshot-probe.mjs`, and `ci-capture-probe.sh` controls, ShellCheck, strict
OpenSpec and the source-manifest check. The route probe exercises the actual
Tcl assertion against matching synthetic text, omitted/wrong child or label,
missing monitor/client, and server-policy-only text; it checks the source and
config differences and rejects the normalized historical copy. The gzip probe
requires each scenario marker and expected producer status. These controls do
not boot Genode or validate the predicted native log ordering. Independent review
of this exact fixture, workflow, provenance and all failure paths is still
required before an experiment.
