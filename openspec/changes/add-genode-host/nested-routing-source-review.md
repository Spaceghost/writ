# Nested Genode routing: pinned-source configuration proposal

A public client named `writ_client_r` requests `Writ_channel` with the existing
literal label `channel`. If a trusted nested init named `clients` forwards that
request to its parent and the parent routes it to the upper monitor, with no
label-rewrite attributes at either hop, the pinned source predicts the monitor
will see `clients -> writ_client_r -> channel`. That is a **source-derived
prediction**, not an observed nested-init result. The existing same-init run
instead observed `writ_client_r -> channel`. No nested configuration has been
implemented or run for this proposal.

This document refines the [reviewed public-fixture plan](nested-routing-fixture-plan.md).
It uses repository commit `bbccf4b04013e04ad85f06d9af19bc03a27afcca` and
Genode 26.08 commit `d18ee9e917200b059549e21f2dd9a55bfe61a0eb` from the
[recorded pins](../../../verification/genode-pins.txt). The local Genode checkout
was clean at that commit when read. The [Genode 26.05 init guide](https://genode.org/documentation/genode-foundations/26.05/system_configuration/The_init_component.html)
provides context about nested routing; the exact 26.08 source below, rather
than a different documentation release, is the basis for the prediction. This
is a proposal for independent review, not a claim of host qualification or a
change to Writ authority rules.
A later [first-slice patch plan](nested-routing-first-slice.md) confines new
native fixture tooling to the approved contribution boundary and does not run it.
The statements above about an unrun nested configuration describe this original
proposal. A later [public route-control retry](../../../verification/genode-route-retry-42361441863/README.md)
observed the predicted R label and a separate missing-route refusal. Both jobs
remained incomplete with in-guest cleanup unverified; neither exercised the
conflicting-policy cases below or established protected-host qualification.

## What the pinned source actually says

Paths in this table are relative to the pinned Genode source tree. The SHA-256
values identify the files read; line numbers identify the relevant definitions.
They do not attest to a future build or prove an observed route.

| Source | SHA-256 | Relevant observation |
| --- | --- | --- |
| `repos/base/src/lib/base/child.cc:140–158, 180–184` | `8b3784854877db36b4ceb3a06f018723ba6410828ef74d2d1a52d1b5e29b4ab2` | `Child::session` prefixes its direct child's policy name to the label from the arguments and passes the routed label to session creation. |
| `repos/base/include/base/session_label.h:24–81, 98–105` | `283c21d2518017fe82164bfe80e425b668ac4c66aca957eef84b3c8f91abfb3c` | `prefixed_label` joins components using ` -> `; `prefix` and `last_element` split at the last such separator. Labels have bounded representation; truncation/invalid-label behavior must be tested rather than guessed. |
| `repos/os/src/lib/sandbox/child.cc:514–590` | `5ab96dfc6e5a19d3f6726eedce89e929aeac9338f2891c78617105bebfa5aeef` | A route target can replace `label`, `identity`, `resource` or `prepend_resource`. Without those attributes, it reconstructs the existing identity prefix and last resource element. |
| `repos/base/include/base/session_state.h:260–275` and `repos/base/include/base/service.h:333–350` | `e7eccd82145104a602d94eff78ccf25ae2fcc01b830065fbea20531e078126e3`; `16245ba41b16e75e861c6b32d3ad98457a7de885cf2c25a0ed0a584712d8d1c0` | `Server_args` replaces the outgoing argument label with the route's label; `Try_parent_service` forwards those arguments via the parent session call. |
| `repos/os/src/lib/sandbox/utils.h:30–110` and `repos/os/src/lib/sandbox/route_model.h:253–276` | `0e00d79d326dd008ea3a487e4fbde93fa4f6184ec0841f3572564e400ad69d8f`; `493b42ea9881c365243bd6ab9b118a31a833b41c6246ce825bcef49483d3d979` | Scoped route selectors remove the direct-child prefix before comparing the child-supplied portion. Explicit service and wildcard route failure have different fallback behavior; configuration order and reachable targets matter. |
| `repos/os/include/os/session_policy.h:35–143, 160–198` | `68a9a438c03601ebaf1ba44f1c39d39b214e1bc601b1c1a18ee7c108f0b806bb` | Server matching scores exact labels, prefixes and suffixes; equally scored later policies do not replace the first. A tie is not an ambiguity refusal. |
| `repos/base/include/util/string.h:134–150, 190–205` | `37a46b286023ba1b113761e131e98f025380f9ade355548724d1dedd419d9740` | Span prefix matching compares bytes, including a successful zero-length prefix; the score logic trims values before matching. It does not enforce a component boundary. |
| `repos/os/src/init/config.xsd` and `repos/os/run/tar_rom.run` | `8fbae1eb5894151e794a7b7b012227dd3490f5fa3fd98f4d4d844999eb3a0d50`; `4d7b6059850dd1d64c6754288ff84798eb996d727053d1387e97a25b788f93ff` | The schema and nested-init example show the relevant configuration shape. The example's broad fallback is not a confinement model. |

The existing Writ client hardcodes `Writ_channel::Connection { _env,
"channel" }` in [writ_channel_client.cc](../../../hosts/genode/probes/client/writ_channel_client.cc).
The existing [channel shim](../../../hosts/genode/shim/writ_mem.cc) calls
`with_matching_policy`; it refuses a default-only, suffix-only, missing, or
zero-subject result, but accepts a prefix-plus-suffix match and does **not**
reject equally scoring conflicting policies. The [same-init runner](../../../scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl)
configures `writ_client_r ->` as subject 1 and `writ_client_s ->` as subject 2.

## Proposed minimum routing shape

This is a deliberately incomplete configuration sketch, **not runnable XML**.
Quota values, runtime ROMs, all required environment routes, supervision and
explicit Timer/LOG treatment must be worked out and independently reviewed
before a test is implemented. The example changes no native code or policy.

```xml
<!-- Parent init: existing monitor and nested init are siblings. -->
<start name="writ_bend_monitor" ...>
  <provides><service name="Writ_channel"/></provides>
  <config>
    <!-- Existing monitor runtime configuration also goes here. -->
    <writ_channel>
      <policy label_prefix="clients -> writ_client_r ->" subject="1"/>
      <policy label_prefix="clients -> writ_client_s ->" subject="2"/>
    </writ_channel>
  </config>
</start>
<start name="clients" ...>
  <binary name="init"/>
  <config>
    <parent-provides><service name="Writ_channel"/><!-- runtime services omitted --></parent-provides>
    <start name="writ_client_r" ...>
      <binary name="writ_channel_client"/>
      <route><service name="Writ_channel"><parent/></service><!-- other required routes omitted --></route>
    </start>
    <!-- Add a separately named S client only for its own control case. -->
  </config>
  <route><service name="Writ_channel"><child name="writ_bend_monitor"/></service><!-- other required routes omitted --></route>
</start>
```

The existing Writ `writ_bend_boot` already builds `core`, `init`, `timer`, and
its monitor; the nested-init example also uses `init` as a child. A future
fixture needs its own generated config, verified parent-provides declarations,
boot artifacts and run assertions, not a new Writ release path. Do not use a
blanket `any-service`/`any-child` fallback as evidence that routes are absent.
For the smallest first public run, instantiate R only, keep the existing 64-byte
request and synthetic Scenario, and check both the client's decision and the
monitor's logged label/subject. Add the S and hostile cases as distinct runs so
an expected setup failure cannot be counted as a policy denial.

For the short fixed names above, the derivation is:

1. R supplies `channel`; the nested init's direct-child handling prefixes
   `writ_client_r`, yielding `writ_client_r -> channel`.
2. The nested route's `<parent/>` target has no rewrite attributes, so the
   routed label is forwarded in parent session arguments.
3. The upper init handles a request from its direct child `clients` and
   prefixes that name, yielding `clients -> writ_client_r -> channel`.
4. The upper route's `<child name="writ_bend_monitor"/>` has no rewrite
   attributes; the monitor receives that label and, for the proposed policy,
   its shim should select synthetic subject 1.

Each step is conditional on the actual component names, route attributes,
configurations, framework revision and successful session setup. Record the
observed labels and decision; a different or missing label is a failed or
incomplete fixture, not a reason to assert this prediction happened. Confirm
label length limits, routing order, any aliases and ROM/config contents in the
specific generated configuration.

## Trust and known conflicting-policy gap

The upper parent directly identifies only its child `clients`. The inner
`writ_client_r` part is supplied through the nested init's routing path. The
nested init binary, its configuration, the outer routing configuration and the
monitor's policy configuration are trusted for this synthetic mapping. If the
nested init or its configuration can be replaced, a requester able to act as
that parent can submit an R-looking remainder; the upper `clients` prefix does
not independently authenticate the inner component or an original human. A
real delegated channel capability also does not authenticate its current holder.

The proposed R and S policies have distinct fixed prefixes and no suffix-based
subject selection. Before launch, trusted configuration review must ensure no
conflicting equal-scoring or overlapping subject mappings and must inspect both
init routing and monitor policies; this is a configuration requirement, not
an existing shim validation feature. In particular, two identical matching R
prefix policies with subjects 1 and 2 are equally scored. Static source
inspection predicts that the first matching entry wins and reversing their
order changes the selected subject. An adversarial test that expects the
**current shim itself** to reject that duplicate configuration is expected to
fail; the shim has no such duplicate-conflict check. No such test has been run.
A future configuration validator or different native behavior would require its
own design and review; this proposal does not implement or assume one.

### Additional source finding: prefix scope and ambiguity veto

This subsection is a read-only source finding at Writ source `ad5e5c0` and
the pinned Genode commit above, not a runtime exploit or a new host result. The
[legacy channel shim](../../../hosts/genode/shim/writ_mem.cc) has SHA-256
`9d9d32d2402bd947c96a4632ae945c6825d1291a3ce97e5ac45b7d0349f71b5d`.
Its `_subject` passes the trusted configuration and routed label to Genode's
`with_matching_policy`, then checks whether the chosen policy has a `label` or
`label_prefix` attribute and has a nonzero subject. It does not check that an
attribute's trimmed prefix is nonempty. The pinned trim removes ASCII spaces,
not arbitrary whitespace. An empty or space-only prefix becomes an empty span
and matches every label; if such a policy is the selected best match, its
nonzero configured subject can be used.
A suffix-only or default winner and a zero subject still produce refusal, and a
rejected winner is not a reason to fall back to a lower-scoring policy.

Likewise, a configured `label_prefix="writ_client_r"` also matches a routed
label beginning `writ_client_r_extra`, because the match is a byte prefix, not
a component-name comparison. This is a possible trusted-configuration error,
not a claim that the client can edit that configuration. The current
[same-init runner](../../../scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl)
uses distinct R and S prefixes ending in ` ->`; the
[nested fixture](../../../contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_accept.run)
uses one nonempty R prefix ending in that delimiter. Those specific policies do
not instantiate the equal-score conflict or empty-prefix examples. The linked
public retry tests R and removal of a route, not these hypothetical policies.
Neither those observations nor this source review prove the nested remainder's
actor identity, nondelegability, current generation, or confinement.

For future independently reviewed work, a narrowly scoped native-fact
ambiguity veto may refuse an ambiguous best-scoring configuration before
channel allocation while continuing to route protected decisions through Bend.
It must not introduce a native authorization or release engine, accept
worker-supplied authority, or reinterpret a refused best match as permission to
try a weaker one. A design must specify the treatment of equal-score identical
subjects as well as conflicting/invalid subjects; calculate ambiguity for the
actual strongest matching policies, including a stronger policy appearing after
an earlier tie; and use the pinned scorer's actual semantics, not a guessed
string equality. It must bound configuration and work, examine the same
trusted configuration snapshot used to derive the subject, and handle malformed,
missing or truncated values fail-closed. The trusted identity namespace,
component-boundary format, empty prefix, and any influence of a client-selected
suffix on subject choice remain separate design questions. This is an
obligation for a future reviewed design, not an implemented veto or a decision
that the demonstrated fixtures are a protected profile.

The shim is existing legacy native code under `hosts/genode/shim/`, outside the
approved new native-source exception at `contrib/native-hosts/`. Its location is
not precedent to add new native code there. Any integration of a future guard
needs a separately reviewed arrangement within the approved boundary and an
updated source/trust inventory; this record changes no C++ or policy law.

Planned synthetic controls, not yet executed, should name and distinguish:

- `equal_best_conflicting_both_orders` and `equal_best_same_subject`: exercise
  conflict order and the explicitly chosen duplicate semantics.
- `later_stronger_clears_prior_tie` and `equal_best_exact_prefix_suffix`: check
  complete pinned score ordering, including mixed selector forms.
- `empty_or_space_only_prefix` and `sibling_byte_prefix`: test the namespace
  rule against empty/space-only values and a longer sibling name, alongside the
  delimiter-terminated current fixture.
- `default_suffix_only_zero_no_fallback` and `unknown_overlong_config`: preserve
  refusal and check malformed/configuration limits without selecting a weaker
  mapping; test a supported valid unique match as a positive control.
- `same_snapshot_and_bounded_scan`: exercise configuration snapshot consistency,
  configured-size boundaries and over-limit rejection; synthetic controls alone
  do not establish the native runtime's configuration lifetime or identity.

Real-host evidence would additionally need a separately reviewed public-only
run with exact source, framework, image and complete route/policy hashes;
positive controls and conflicting-policy refusals in both orders; observed
session-open/refusal and subject logs; and recorded exits, resource cleanup and
failure scope. Actual actor/delegation authentication, reconfiguration and
generation revalidation, mediation of every effect, and protected-input and
release gates remain separate acceptance work. None is established by adding
this source note or by the existing route-control pair.

## Review cases and remaining gaps

- Reuse the existing R accept, R body-claims-S/session-S rejection, and routed-S
  controls with trusted fixed policies; require the actual label/subject and
  exact recorded reason separately. The body cannot choose its route subject.
- Add a public adversarial client that chooses an R-looking suffix and a
  similarly prefixed sibling name. The existing client hardcodes `channel`, so
  suffix variation needs a separate test-only probe or a reviewed test-only
  change; it is not covered by the existing client. Reject any result that
  grants R through an untrusted suffix or misattributes S as R.
- Remove a route, remove a policy, use a zero subject, create conflicting
  duplicate policies, and exercise quota shortage separately. Capture whether
  refusal happens at routing, session setup, descriptor admission, or the Bend
  gate; do not call setup failure a completed policy denial. For conflicting
  policies, distinguish a pre-launch configuration-review refusal from the
  currently non-rejecting shim behavior described above.
- Account for each parent/session donation and adjustment. The existing client
  donates 32 KiB and eight caps; the shim requires at least 16 KiB and its cap
  minimum. `Child::session` deducts session metadata at each hop, and local
  service accounting may adjust donations. Whether the existing donation
  suffices through nested init is unverified; record the actual setup or
  shortage instead of treating the same-init quota as a guaranteed nested one.
- Test session close and plan separate restart/reconfiguration cases. The shim
  binds a subject at creation; this does not establish GN-005 revalidation of
  an existing session after route or authority generation changes.

The fixture may use only public values and test-only logs. It does not prove
complete effect confinement, current actor or delegation authentication,
capability non-transferability, revocation, sealed output, durable publication
or protected-host qualification. Base-linux, base-hw/QEMU and physical hardware
remain separate profiles. Use a fresh isolated build and bounded process
teardown as described in the [fixture plan](nested-routing-fixture-plan.md),
retain exact inputs/configs/logs/refusals, and seek independent review before
implementing or running the proposal. q18 items 7–10 remain unanswered as
recorded; no existing authority law or task status changes here.
