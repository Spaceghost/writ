# Synthetic public boot manifest publication

A synthetic observer can return 14 public digests in memory, but a file named
`manifest` alone does not show that all bytes were written or that its writer
exited successfully. The smallest independently testable next slice is a
fixed-format, bounded **synthetic partial** manifest and a separately staged
status binding its exact bytes. It performs native filesystem packaging only;
it does not authenticate an observer, certify a fixture, grant Writ authority,
claim boot consumption or establish host qualification.

The fixed packaging slice has [synthetic controls](../../../verification/genode-synthetic-publication/README.md); no actual worker or workflow calls it. The [current partial observer](same-fd-exact-config-design.md)
has no publication caller. The writer described here is not connected to a
fixture, worker, workflow, or protected data. The [full inventory design](disposable-boot-inventory-design.md)
and [supervisor](disposable-fd-supervisor-design.md) remain incomplete. A
caller can fabricate a correctly formatted observation and its hashes; a
syntactically valid pair is not evidence that the observer ran. A digest is
information, so inputs are confined to fixed public synthetic data.

## Canonical bytes and validation

The trusted test caller supplies a fixed scenario enum, unsigned 64-bit run
and attempt numbers and a fixed-size, typed 14-slot `{size, digest}` observation.
The caller must provide valid storage; the implementation must statically tie
its slot count to the fixed observer structure and check each index before
access. These numbers are non-authoritative labels, not authenticated identities or replay
protection. The writer does not accept paths, entry names, arbitrary fields,
callbacks or a caller-selected status. It encodes ASCII exactly as follows,
with `\n` denoting one byte `0x0a` and no extra whitespace or trailing bytes:

```text
WRIT-PUBLIC-BOOT-MANIFEST-V1\n
scenario=<positive|negative>\n
run=<decimal-u64>\n
attempt=<decimal-u64>\n
<fixed-name> size=<decimal-u64> sha256=<64-lowercase-hex>\n
... exactly 14 fixed-name lines in the order below ...
```

This block describes line syntax; the ellipsis is never emitted. Decimal is
canonical unsigned base 10: `0` or a nonzero digit followed by digits, with no
sign, leading zero, locale formatting or exponent. Each digest is exactly the
64 lowercase hexadecimal digits of its fixed 32-byte input, including leading
zeros. The 14 names and slot order are fixed in source:

```text
config
core
hpet_timer
init
init.hsd
init.xsd
ld.lib.so
libc.lib.so
libm.lib.so
timer
vfs.lib.so
vfs_pipe.lib.so
writ_bend_monitor
writ_channel_client
```

The `config` size/digest must match the selected scenario's fixed installed
public vector (positive 1,710 / `2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22`;
negative 1,668 / `e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a`).
This check rejects inconsistent synthetic records; matching a caller-supplied
hash does **not** independently establish that exact config bytes were read.
Every other size is at most 268,435,456 bytes; checked addition over all 14
sizes must be at most 1,073,741,824 bytes. Validate the fixed array dimensions
and all bounds before formatting; never index an unchecked caller value,
truncate an entry or normalize a malformed record. The longest format under
these limits is at most 1,466 bytes; enforce an independent 4,096-byte manifest
cap and fail incomplete on any arithmetic, formatting, hash or size error.
No native policy, label, authorization, state transition or release decision
is introduced by these fixed packaging rules.

The separate status has this exact ASCII syntax, again without the placeholder
notation or additional bytes:

```text
WRIT-PUBLIC-BOOT-STATUS-V1\n
status=synthetic-partial\n
scenario=<positive|negative>\n
run=<decimal-u64>\n
attempt=<decimal-u64>\n
manifest_bytes=<decimal-u64>\n
manifest_sha256=<64-lowercase-hex>\n
```

`manifest_bytes` and `manifest_sha256` are the exact length and SHA-256 of the
fully formatted manifest bytes; scenario, run and attempt must match. The
status cap is 512 bytes (the format is at most 225 bytes under the stated
bounds). This status only records the writer's intended synthetic partial
pair. It never says `complete`, carries no general actor identity, and cannot
attest that the observation or writer is authentic. A test-only consumer may
check canonical syntax, exact fixed names/order, bounds, status/manifest keys,
length and digest; it must not treat a match as an admission or completed
inventory.

## Fixed held directory, staging and interruption

A future synthetic packaging function receives only an already held, trusted,
exclusive owned output-directory FD and the bounded fixed inputs. Verify its
directory type, owner, intended restrictive mode and close-on-exec; the caller
retains ownership of that FD and must provide an exclusive, stable FD table.
The directory and its contents must not be concurrently modified by another
thread or same-UID process. The current helper cannot establish these
preconditions. No arbitrary directory path, name, root or destination comes
from a workload; future VM integration requires the separately reviewed
supervisor to establish and bind the directory before any child can modify it.

Build the complete manifest and status in fixed-size memory, with checked
arithmetic and a trusted native SHA-256 implementation. Use only the four
fixed names `public-manifest.tmp`, `public-manifest.txt`, `public-status.tmp`
and `public-status.txt`. Temporary names are never on an upload allowlist.
Create each temp by descriptor-relative `openat` with
`O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`, mode 0600, and check regular
file, owner, link count and identity. Write all bounded bytes with checked
partial-write/EINTR handling; failure is incomplete. Check the write FD's
close once and never retry a possibly reused number. Check the temp identity
and contents through a bounded no-follow, descriptor-anchored readback, then
close/check the read FD. The output-directory exclusivity assumption is
necessary: checking a pathname before a later promotion cannot by itself
exclude same-UID replacement or an A→B→A race.

Promote the manifest with `renameat2(RENAME_NOREPLACE)` relative to the held
directory, refusing unsupported flags or an existing destination. Reopen only
that fixed final name with no-follow, verify its identity, exact bounded bytes,
length and SHA-256, and check its close. Then create, write, close and promote
the status in the same way; never overwrite or follow an existing temp/final
object. Recheck the final pair under the trusted directory before returning a
local successful **synthetic-partial packaging** status. Any failed write,
close, readback, identity, rename or status operation returns incomplete or
cleanup-unverified as appropriate; retain no arbitrary names or file contents
in diagnostics. If cleanup is attempted, unlink only a temp object whose
creation and still-matching identity are owned by this call; uncertainty is
not permission to delete a substituted object. Do not auto-delete or reuse a
pre-existing final, even after a prior incomplete attempt.

The two final files cannot be promoted atomically together. Interruption after
manifest promotion may leave an uncredited manifest. Interruption after status
promotion may leave a correctly matching pair **even though the writer did not
exit successfully or finish later checks**. Therefore final-file existence,
matching bytes or a status file alone must never confer completion. Before any
future complete-inventory credit, a separately trusted supervisor must bind
this exact output-directory lifetime, invocation/scenario, worker identity,
verified worker exit and its own complete control/cleanup outcome, then check
the pair; that supervisor does not exist here. A missing/failed worker result,
timeout, late close failure, orphan, malformed status, conflicting final or
uncertain cleanup is incomplete. A future supervisor's separate bounded
failure-status record is also not implemented by this synthetic writer.

No `fsync` or persistence protocol is specified; success is not a durability
or crash-recovery claim. Neither fixed file caps nor nonblocking flags bound a
stalled filesystem syscall. Independent wall supervision, mount/FD-table
ownership, post-publication replacement prevention and VM teardown are
outside this slice and remain prerequisites for any later real run.

## Owned-temporary synthetic controls

The recorded controls run on exclusive test-owned temporary directories and files; no
fixture, Genode/QEMU, protected input, worker or workflow is started.

* `canonical_pair_both_scenarios` compares every output byte with independently
  constructed full expected 14-line manifests and status records, including
  `0`, large u64 identifiers, maximum legal sizes, zero/leading-zero digest
  bytes and the scenario's pinned config entry. Recompute hash independently.
* `bad_input_bounds` rejects unknown scenario, wrong config size/digest,
  oversized leaf, aggregate overflow/limit, and any formatter/output-cap
  fault, with no final pair. No synthetic caller input establishes authority.
* `no_overwrite_or_follow` tests pre-existing temp/final files, symlinks,
  FIFOs and a test-owned socket for each fixed name, and renameat2 unsupported
  errors. Fail incomplete, do not open a special object as data, overwrite a
  sentinel or mutate an unrelated path. Same-UID concurrent substitution is
  not claimed to be prevented by these tests.
* `write_close_readback_failures` injects short writes/EINTR, hard write,
  close, bounded read, wrong content/identity and hash failures at each stage.
  A real close failure or blocked syscall is not certified recovered by a
  synthetic injection; no unchecked partial output receives credit.
* `interruption_matrix` interrupts a known test-owned child before/after
  each write, checked close and promotion. An orphan temp or manifest is not
  a completed pair. After status promotion, a matching pair can still remain;
  assert that the absent/nonzero independently observed child-exit result
  prevents any synthetic consumer from calling that run complete.
* `binding_and_replay` changes one status byte, size, digest, scenario, key,
  entry order/name, decimal representation, trailing byte or manifest byte;
  the test validator rejects it. An unchanged copied pair can still match:
  replay/authentication is an explicit future supervisor responsibility, not a
  property of this format.

A source inventory, normal/UBSan native synthetic checks, required Bend
suite/proof, strict OpenSpec and manifest are needed before source review.
Keep all outputs outside the checkout except fixed text evidence; report no
GPU, Genode or host qualification. If directory exclusivity, no-overwrite
promotion or safe lifecycle cannot be established, stop and report incomplete
rather than falling back to pathname writes or claiming a complete inventory.
