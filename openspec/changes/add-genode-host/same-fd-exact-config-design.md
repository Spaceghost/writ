# Proposed exact public configuration check during held-FD hashing

The current public partial observer can hash a `config` inode whose bytes are
wrong: a matching-length regular file is sufficient for its layout check. The
next synthetic slice would compare every config byte with the fixed expected
public scenario **during the same read** that feeds its digest. A mismatch
would leave all caller outputs zero and the observation incomplete. This is not
a complete inventory, a Writ policy decision or evidence of what an earlier
Genode process consumed.

The [same-FD observer](same-fd-observation-design.md) already retains the
validated `config` descriptor, reads it through the checked procfs FD view and
revalidates fixed paths afterward. The new check belongs in that same native
public-fixture I/O path; it must not reopen `config` by name or read it a
second time for comparison. Its caller, trusted exclusive stable process FD
table, kernel, mount namespace, procfs and OpenSSL EVP/provider environment
remain trust assumptions. A digest and match result are information: only the
fixed public fixture is in scope. A same-inode FD-number replacement can be
closed without detection, as [already observed](../../../verification/genode-boot-same-fd/README.md).
No real worker may use this probe until the separate FD-table boundary is
established and reviewed.

## Fixed references and same-read rule

Use exactly the independently reviewed, tracked public argument references,
with the **one additional LF** written by the Genode installer. The
references already end in LF, so the final installed byte sequence ends in two
LF bytes; do not trim, normalize, recode or compare only a hash.

| Fixed scenario | Argument bytes / SHA-256 | Installed bytes / SHA-256 |
| --- | --- | --- |
| Positive | 1,709 / `9832324d540f478108e0df4063468163702be4b2716ffb0663e59e35fe7e577e` | 1,710 / `2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22` |
| Route-negative | 1,667 / `bb05c8aef62045425f71da1fee373b06e9b8539adc457592fdb50266856fe48c` | 1,668 / `e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a` |

The [argument provenance and archived-config comparison](../../../verification/genode-fixture-config-guard/README.md)
and [guard design](public-fixture-config-guard-design.md) are independent of
this new check. A digest records bytes; it does not authenticate their origin.
An implementation may embed two private constant byte arrays in native probe
source, derived once from the fixed reviewed argument files plus the specified
LF, and must independently verify each array byte-for-byte against both its
tracked argument file and the corresponding separately retained historical ZIP
member. Record exact lengths, full hashes, source commit and generation method.
These are fixed public data constants, not generated Bend backend code. Do not
regenerate expected data at runtime from the observed config, accept an
expected pathname/reference supplied by a fixture, or infer it from its digest.
The arrays and containing binary are trusted reviewed inputs, not writable
shared mappings; a same-UID memory attacker or mutable binary can defeat that
assumption. This synthetic slice starts no writable fixture child, so it does
not establish a pre-fixture pin. Before any future VM use, the reviewed
supervisor must establish and retain the expected bytes and code identity
before starting any writable child, as its separate design requires; loading a
mutable executable or reference only afterward is insufficient.

The existing fixed scenario enum alone selects the corresponding private
constant; reject any other scenario before reading. The caller supplies no
expected bytes, lengths, digest, path, predicate or policy. The public API
continues to return the distinct `WRIT_PUBLIC_PARTIAL_OBSERVATION` status only
after all 14 reads, post-read checks and checked closes; this status remains
partial because an independently supervised overall deadline, exclusive
publication and host integration do not exist.

In the held-read implementation, use one internal fixed config mode that takes
the same held `O_PATH` inode and fixed scenario. For each successful bounded
read, check offset/length using overflow-safe arithmetic before accessing the
selected reference, compare the **same bytes** at that offset which are passed
to `EVP_DigestUpdate`, and advance the offset only after both operations
succeed. Require the original and read length to equal the chosen fixed
installed length, exactly the expected final LF, and an actual EOF on the
existing one-byte growth probe. An unexpected NUL, non-ASCII byte, changed
byte, missing/extra data, premature EOF, read/hash/compare error, unsupported
primitive, length or metadata drift is incomplete. A positive short read is
processed and followed by another bounded read; it is not itself an error. Exact equality already
rejects NUL/non-ASCII; any explicit checks must not weaken equality. Never
materialize untrusted input in diagnostics. The other 13 entries retain their
existing fixed per-file bounds, checked aggregate total and same-FD revalidation.

Existing standalone `writ_boot_read_held` remains a general trusted-FD hash
probe with its present interface and historical behavior; exact scenario
selection is a private internal mode used only for observer index zero. No
runtime callback, writable reference buffer, caller-provided file or arbitrary
path becomes a new authority or policy input. The production dynamic export
surface must remain unchanged. All outputs remain zero on any error and on
cleanup uncertainty; propagate reader close failure distinctly as today.

## Limits and planned synthetic controls

The config comparison and digest describe the byte stream observed in this one
read. Stable metadata before/after, held inode identity and post-read path
checks do not freeze contents, rule out adaptive A→B→A changes, authenticate
the process, verify that an earlier fixture consumed the same bytes, or prove
cleanup. Per-read monotonic checks cannot interrupt blocked I/O or bound 14
files in aggregate. No config result grants admission, creates an output file,
publishes a manifest or qualifies a host. The [supervisor design](disposable-fd-supervisor-design.md),
exclusive worker FD-table boundary, overall deadline and publication remain
unimplemented; do not integrate into a workflow or run Genode/QEMU.

Tests use only owned temporary public files and test-only fault hooks compiled
out of production. Independently verify both embedded fixed references and
archived ZIP bytes, then exercise:

* `exact_positive` and `exact_negative`: each fixed installed vector succeeds
  in its scenario, with expected size/digest and the same retained FD; scenario
  swap is incomplete with zero outputs.
* `fixed_byte_mutations`: first, interior and last byte changes, wrong route
  variant, missing or extra LF, strict prefixes/extensions, embedded NUL and
  non-ASCII bytes fail exact comparison even when the length remains valid.
* `bounded_stream`: test-only short-read chunking crosses reference boundaries;
  EINTR is retried, exact EOF is required, and short EOF or a growth probe
  causes incomplete. A test-only observation must establish that every byte
  sent to hashing is the same byte sequence and order checked against the
  reference, without retaining arbitrary data.
* `comparison_or_digest_failure`: inject separate read, comparison, digest
  update/final and close failures. All caller outputs remain zero; simulated
  close failures remain cleanup-unverified rather than ordinary mismatch.
* `postread_mutation`: same-size content/metadata drift and fixed-path or link
  replacement after the read are incomplete. Test hooks exercise stages and
  markers without claiming detection of adaptive A→B→A changes.
* `reference_integrity`: changing an embedded byte, selecting the wrong fixed
  scenario or changing the trusted source/reference after the pre-pinned
  constant was produced must not silently rewrite expectations. Verify
  independent fixed hashes and historical archive membership; test-only
  mutated copies never become the normal expected data.
* `compatibility`: preserve standalone held-read hashing and existing
  layout-only behavior. Keep the out-of-range index and 14-entry output caps,
  all-zero late-failure, ownership and 511 prior composition controls.

Run the synthetic normal and UBSan controls, native compiler checks, pinned
Bend tests and available Lean verdict, strict OpenSpec and source manifest.
Keep generated native binaries outside the checkout. Record exact commands,
source/reference identities, unsupported cases and no GPU/host claim.
