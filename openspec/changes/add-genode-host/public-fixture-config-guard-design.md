# Fixed-configuration guard for the public Genode fixture

Suppose the public nested-R test's generated monitor configuration gains a
second `writ_client_r` policy. The current channel shim can choose the first
of two equally scored policies. The fixture guard is designed to stop this
supervised fixture before boot because its complete generated configuration is
not the independently reviewed, exact fixture configuration. It would not fix
the shim or evaluate arbitrary route policies.

The contribution-owned guarded entry points and offline synthetic controls are
now implemented and inventoried in the [Genode contribution](../../../contrib/native-hosts/genode/README.md#experimental-nested-channel-fixture).
No guarded Genode run, host acceptance test, or host qualification is claimed.
The [source review](nested-routing-source-review.md)
describes the tie, empty-prefix and byte-prefix hazards. The public
[route-control retry](../../../verification/genode-route-retry-42361441863/README.md)
observed an R session and a separate missing-route refusal; both jobs remained
incomplete with in-guest cleanup unverified. Its fixture does not test ambiguous
policies, and the proposed guard does not change those historical results.
All [Genode host tasks](tasks.md) remain open.

## Actual installation boundary and reference bytes

The current [nested fixture](../../../contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_accept.run)
sources `writ_bend_monitor.tcl` and calls `writ_bend_boot` with fixed R policy,
client, route and quota text. The existing
[`writ_bend_boot`](../../../scripts/genode/writ_bend.tcl) first builds targets,
then calls `install_config` with **one Tcl string** containing the complete
rendered init configuration, then calls `build_boot_image`. Thus a refusal at
`install_config` is before boot and image construction, not before compilation.
The pinned Genode 26.08 commit is
`d18ee9e917200b059549e21f2dd9a55bfe61a0eb`;
its `tool/run/run:313–327` joins `install_config` arguments with an empty
separator, opens the boot module `config`, and uses Tcl `puts` to write it.
The original fixture later calls `run_genode_until` once. The existing
[structural stub](../../../contrib/native-hosts/genode/nested-channel/check-structure.tcl)
captures the input argument without installing or parsing it.

A read-only replay of that stub on the fixed positive fixture produced an
ASCII argument of **1,709 bytes**, SHA-256
`9832324d540f478108e0df4063468163702be4b2716ffb0663e59e35fe7e577e`.
The later retry's original artifact contains an installed positive config of
**1,710 bytes**, SHA-256
`2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22`:
it equals the argument followed by one LF. This comparison is reproducible
from [the archived positive ZIP](../../../verification/genode-route-retry-42361441863/raw/positive.zip)
and its [config audit](../../../verification/genode-route-retry-42361441863/positive-config-audit.txt).
The earlier `genode-nested-ci-7b31cfc` text capture has 1,709 bytes; its
normalization must not be used to infer the installed-file terminator. The
argument/installed distinction and Tcl encoding/translation are part of the
test contract, not assumptions to silently normalize.

The retry's separately audited route-negative config removes exactly one
nested-client line `  |     + service Writ_channel | + parent` and its LF.
The [negative ZIP](../../../verification/genode-route-retry-42361441863/raw/negative.zip)
contains **1,668 installed bytes**, SHA-256
`e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a`.
Removing its final installer LF yields **1,667 argument bytes**, SHA-256
`bb05c8aef62045425f71da1fee373b06e9b8539adc457592fdb50266856fe48c`.
The [negative config audit](../../../verification/genode-route-retry-42361441863/negative-config-audit.txt)
records this fixed change and notes that the negative fixture's terminal
assertions differ. This negative denies a route during setup; it is not a Bend
policy denial. These hashes identify historical bytes, not authority or proof of
what another process installed.

## Proposed guarded entry points

The new test tooling is under `contrib/native-hosts/genode/nested-channel/`.
Keep the legacy shim, `writ_bend.tcl`, existing client and Bend monitor unchanged.
A positive entry point sources the existing fixed R fixture; the separate
route-negative entry point uses the tracked exact archived fixture variant
with that one route removed and its route-refusal assertions. Neither entry point
accepts a caller-supplied subject, policy, configuration path, expected digest,
mode switch or arbitrary Tcl script. The two entry points bind their own exact
reference bytes and expected observation; selecting the negative must never
make a missing route count as an R success.

Before sourcing the fixed fixture, the contribution-owned wrapper renames and
wraps only the existing Tcl `install_config` procedure. Offline controls exercise
the real Writ boot helper with the original installer stubbed; a guarded Genode
run remains unperformed. This is not an interception point in the shim. The
wrapper forwards the unchanged argument once after exact comparison. It does not
wrap or change `build_boot_image` or `run_genode_until`, parse policy, rewrite
configuration, or select an actor. Each invocation is validated independently;
there is no native policy or lifecycle state machine and no one-shot latch.
The reviewed fixture calls the installer once. If a future caller invokes it
again, each valid invocation is forwarded and each invalid one is refused; the
guard does not itself enforce a total invocation count.

At `install_config` require exactly one argument, at most **16,384 characters**
before any conversion or comparison, and ASCII only. The fixed expected argument
is 1,709 or 1,667 ASCII bytes, respectively. Reject overlength, non-ASCII, NUL,
missing or extra arguments before forwarding. After the cap and ASCII checks,
compare the entire original string to its selected fixed reference; no trimming,
newline conversion, prefix checks, substring matching, or policy-field repair.
Unknown bytes, extra or omitted policies/routes, changed ordering, and even a
benign formatting change must refuse the invocation. Caps limit the guard's
additional comparison work; they do not bound construction of a Tcl string
already supplied by its trusted producer.

Only after exact comparison may the wrapper call the original installer with
the unchanged one argument. Installer errors propagate. The controlled entry
point must source the fixed fixture under a top-level error handler that exits
nonzero on mismatch or installer failure, with no fallback or retry; in the
reviewed fixed call path, `writ_bend_boot` calls `install_config` before image
construction and the fixture calls `run_genode_until` afterward. The existing
fixed fixture has no inner handler that catches an installation error and
continues. This ordering is an assumption to verify against each pinned script,
not enforcement against arbitrary Tcl. If the original installer has already
had an effect before failing, preserve the failure; do not claim it was undone.
If the pin/tool/runtime cannot generate the exact argument, stop rather than
derive a replacement reference automatically.

The guard does not open, inspect, or verify the installed file and does not
intercept boot or runtime waits. In particular, it makes no no-follow,
nonblocking, regular-file, or concurrent-replacement claim; a future installed
file checker would require a separately reviewed descriptor-based OS design.
The guard opens its trusted reference path before its bounded read. The byte cap
does not bound that open/read's latency or prevent a FIFO, symlink, or same-UID
replacement; a separately bounded outer supervisor is needed to bound a stall.
A trusted post-run collector may record the installed bytes as an observation,
but that capture is not a pre-boot guard or proof of what Genode consumed.
For these Linux fixture inputs the historically installed form is the argument
plus one LF, exactly as observed above; changed Tcl encoding or line translation
remains an unverified delivery gap, not a reason to normalize the guard input.

The route-negative experiment can call `run_genode_until` multiple times while
waiting for late markers from the same existing spawn. The proposed guard must
leave that pinned continuation logic and its overall deadline unchanged; a
repeated wait must not be mistaken for another launch. A future negative fixture
still needs independent review of its exact source and bounded waits.

## Reference ownership and trust

Each reference is a separate, committed byte fixture with a recorded
length and SHA-256, reviewed against the fixed source and archived evidence above.
The expected bytes and scenario selection must be fixed before generating the
runtime argument. The test must never copy the just-generated argument into its
own reference, compute its expected hash from the same invocation, accept an
environment-selected reference, or update a reference merely to make a test
pass. Full byte comparison supplies the gate; a digest is an inventory aid, not
an authentication credential. A change to either fixture or reference requires
a new review of both the intent and exact bytes.

The trust root is still the pinned, reviewed checkout and controlled tooling:
an actor who can alter the wrapper *and* its committed reference can defeat
this check. Pinning a Git commit/hash or placing files in a private directory is
not by itself independent process attestation. Before any real public fixture
run, independently record the wrapper, reference, fixture, source overlay,
Genode/toolchain and build/boot inputs and hashes; record the staging procedure
and any independently captured installed/boot configuration; and preserve status,
refusal and cleanup records. The existing [overlay preparer](../../../contrib/native-hosts/genode/nested-channel/prepare-overlay.sh)
copies the legacy `writ_mem.cc` byte-for-byte and hashes its staged inputs;
any new wrapper/reference files must also be inventoried and staged by an
explicit reviewed arrangement. The pinned `run_boot_dir` and `power_on` path,
run directory, binaries, Tcl interpreter and supervisor remain trusted. The
legacy source stays outside the approved new native-source exception; this plan
adds no code there.

The argument comparison does not prove that the same bytes were installed or
consumed: the file may change after installation or be substituted by another
same-UID actor; the build tool may transform or use a different object; direct
invocations of an unwrapped installer, boot helper or old fixture can bypass
the wrapper. The wrapper is a controlled test guard, not a sandbox against
malicious Tcl in the same interpreter. A future implementation must keep all
unverified delivery intervals explicit; protected profiles would need their own
live, current configuration and authority binding. This guard neither validates
subject identity nor checks runtime configuration changes, delegation, complete
routes, confinement, cleanup or revocation. Public LOG and the broad outer
fallback remain in the existing fixture.

## Planned offline controls and later evidence

The contribution's named offline controls use Tcl stubs that record installer,
image-build and launch calls and cannot spawn Genode or QEMU. They source the
actual `writ_bend_boot`, fixed positive fixture and fixed negative fixture under
those stubs. Their exact names and captured outcomes are in the
[local verification record](../../../verification/genode-fixture-config-guard/README.md).
The names below are design scenario groups, not necessarily individual assertion
names; the bypass item documents an explicit limitation rather than a security
sandbox test.

- `positive_exact_and_installed_lf`: the independent positive vector forwards
  exactly once; an offline installer stub reproduces and checks the pinned
  `puts` behavior of adding one LF. The guard does not inspect a real file.
- `negative_exact_distinct_entry`: the independent missing-route vector passes
  its own fixed gate; positive and negative references cannot be interchanged.
- `policy_conflict_and_prefix_mutations`: added duplicate/conflicting subject,
  empty/space-only prefix, removed delimiter, reordered policy, changed route
  and changed subject each fail byte comparison before installer invocation.
- `format_and_boundary_mutations`: missing final argument LF, extra LF/space,
  NUL, non-ASCII, extra argument, missing argument, exact-cap and cap+1 inputs
  fail without forwarding unless identical to the fixed under-cap reference.
- `installer_error_no_boot`: a failing original installer causes the controlled
  outer entry point to exit; the test observes no image-build or launch call,
  without claiming to reverse any earlier installer side effect.
- `repeated_install_is_checked`: each valid call is forwarded and a subsequent
  changed call is refused; the fixed entry point propagates a fixture error to
  nonzero exit without boot. It does not undo an earlier successful install or
  prevent arbitrary Tcl from invoking unwrapped procedures.
- `negative_late_marker_continuation`: the fixed negative run's offline stub
  delivers markers in a late arrival order and verifies that repeated waits on
  the original spawn and their deadline are passed through unchanged.
- `reference_mismatch_and_source_parity`: corrupted expected bytes or hash
  inventory fail verification; independently generated positive and reviewed
  negative vectors match the pinned historical bytes, without updating them.
- `raw_bypass_is_not_containment`: document that calling a renamed original or
  the legacy runner outside the controlled entry point is outside the guard's
  trust boundary; do not represent a Tcl wrapper as a malicious-code sandbox.

A later separately reviewed public-only execution must capture the guard's
status and exact configuration at each supported observation, independently
identified source/toolchain/boot inputs, existing positive or negative fixture
outcomes, timeouts, and the actual cleanup result. A mismatch or missing
observation is incomplete. Such a run would not establish arbitrary-policy
ambiguity rejection, actor identity, protected data confinement or Genode host
qualification. No Genode/QEMU execution or workflow dispatch was performed for
this design.

The [bounded post-run boot inventory proposal](disposable-boot-inventory-design.md)
addresses the pinned Linux boot tree's two-hop symlinks. It is design-only;
neither its collector nor a guarded fixture run is established by this note.
