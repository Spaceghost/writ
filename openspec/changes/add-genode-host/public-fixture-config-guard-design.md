# Proposed fixed-configuration guard for the public Genode fixture

Suppose the public nested-R test's generated monitor configuration gains a
second `writ_client_r` policy. The current channel shim can choose the first
of two equally scored policies. A proposed guard would stop this particular
supervised fixture before boot because its complete generated configuration is
not the independently reviewed, exact fixture configuration. It would not fix
the shim or evaluate arbitrary route policies.

This is **design only**: no guard, guarded run, new acceptance test, or host
qualification is claimed. The [source review](nested-routing-source-review.md)
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

Add new test tooling only under `contrib/native-hosts/genode/nested-channel/`.
Keep the legacy shim, `writ_bend.tcl`, existing client and Bend monitor unchanged.
A positive entry point may source the existing fixed R fixture; a separate
route-negative entry point would need its own fixed, reviewed fixture variant
with that one route removed and its existing route-refusal assertions. The
negative variant is not currently a tracked guarded fixture. Neither entry point
accepts a caller-supplied subject, policy, configuration path, expected digest,
mode switch or arbitrary Tcl script. The two entry points bind their own exact
reference bytes and expected observation; selecting the negative must never
make a missing route count as an R success.

Before sourcing the fixed fixture, a contribution-owned wrapper may rename and
wrap the existing Tcl `install_config`, `build_boot_image`, and
`run_genode_until` procedures. This is a proposed mechanism requiring offline
validation against the pinned tool; it is not an existing interception point in
the shim. The wrapper must preserve the exact original arguments and delegate
once, without parsing policy or rewriting the generated configuration. It is
not a general-purpose selector, configuration editor, authority service, or
way to route a protected request.

Use a monotone one-shot state machine: initially `Ready`; one installation
attempt may progress through `Installing` to `Installed`; one image build and
one fixture launch may then progress through `Building`, `Built`, `Launching`
and `Consumed`. A wrong order, second call, mismatch, exception or failed
readback permanently poisons that invocation. A poisoned or incomplete state
must block both the wrapped image build and fixture launch, even if a surrounding
Tcl caller catches the original error. The guard must not re-open a poisoned
invocation or fall back to the unwrapped procedure. If the delegated installer
or builder has already had an effect, preserve the failure; do not claim it was
undone. The trusted wrapper must preserve the original fixture's error handling,
exit statuses and positive/negative outcome checks.

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
the unchanged one argument. It must check the returned status and then read back
the installed configuration through a bounded **cap+1** byte read, rejecting a
missing, non-regular, unexpected link, oversized, short, different or otherwise
unverifiable file. For these Linux fixture inputs the expected installed bytes
are the fixed argument plus one LF, exactly as observed above; any different Tcl
encoding or line ending is incomplete, not normalized. Check the same expected
installed bytes again immediately before the wrapped image build and immediately
before the wrapped fixture launch. Resource ownership, path resolution, file
lifetime and read failures need explicit implementation review: checks are
observations in a trusted private run directory, not a claim of atomicity or
proof against a concurrent same-UID writer. If the pin/tool/runtime cannot produce
these exact bytes, stop rather than derive a replacement reference automatically.

## Reference ownership and trust

Each future reference must be a separate, committed byte fixture with a recorded
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
Genode/toolchain and build/boot inputs and hashes; verify the staging procedure
and installed/boot configuration; and preserve status, refusal and cleanup
records. The existing [overlay preparer](../../../contrib/native-hosts/genode/nested-channel/prepare-overlay.sh)
copies the legacy `writ_mem.cc` byte-for-byte and hashes its staged inputs;
any new wrapper/reference files must also be inventoried and staged by an
explicit reviewed arrangement. The pinned `run_boot_dir` and `power_on` path,
run directory, binaries, Tcl interpreter and supervisor remain trusted. The
legacy source stays outside the approved new native-source exception; this plan
adds no code there.

Checking a path before image construction and launch does not prove that the
same bytes were consumed: the file may change between observations or be
substituted by another same-UID actor; the build tool may transform or use a
different object; direct invocations of an unwrapped installer, boot helper or
old fixture can bypass the wrapper. The wrapper is a controlled test guard, not a
sandbox against malicious Tcl in the same interpreter. A future implementation
must document and test supported ownership/lifetime controls and keep any
unverified interval explicit; protected profiles would need their own live,
current configuration and authority binding. This guard neither validates
subject identity nor checks runtime configuration changes, delegation, complete
routes, confinement, cleanup or revocation. Public LOG and the broad outer
fallback remain in the existing fixture.

## Planned offline controls and later evidence

These named controls are proposed; none is claimed to have run for the guard.
Run them with Tcl stubs that record installer, image-build and launch calls and
cannot spawn Genode or QEMU. Source the actual pinned `writ_bend_boot` and the
fixed positive fixture under those stubs, rather than testing only a duplicate
handwritten configuration. Exercise the separately reviewed fixed negative
variant the same way. Capture input/reference hashes and expected status.

- `positive_exact_and_installed_lf`: the independent positive vector forwards
  exactly once; the delegated installed bytes include exactly one added LF.
- `negative_exact_distinct_entry`: the independent missing-route vector passes
  its own fixed gate; positive and negative references cannot be interchanged.
- `policy_conflict_and_prefix_mutations`: added duplicate/conflicting subject,
  empty/space-only prefix, removed delimiter, reordered policy, changed route
  and changed subject each fail byte comparison before installer invocation.
- `format_and_boundary_mutations`: missing final argument LF, extra LF/space,
  NUL, non-ASCII, extra argument, missing argument, exact-cap and cap+1 inputs
  fail without forwarding unless identical to the fixed under-cap reference.
- `readback_failure`: failed installer, missing/changed/oversized installed
  file, unexpected link and read error each poison; no build or launch follows.
- `one_shot_and_caught_failure`: duplicate install/build/launch, wrong order and
  a caught mismatch cannot later reach image construction or launch.
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
