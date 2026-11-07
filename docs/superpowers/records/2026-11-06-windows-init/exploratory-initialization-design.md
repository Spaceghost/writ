# Proposed exploratory no-data initialization experiments

Status: reviewed design with the first same-lifetime slice implemented for source/workflow review; no experiment below has been built or run on Windows. The actual byte-worker profile and strict native gate are unchanged. Any contrast that requires an independently verified fact we cannot obtain, including the full pre-resume environment, remains **inconclusive as a controlled comparison** even if its raw observations differ.

The separate [no-data initialization run](run-42313767360/README.md) reproduced Winsock `10107`, USER32 `1114` and OLE32 `1359` in a zero-capability, Win32k-disabled LPAC; its ordinary controls succeeded. The separate [LPAC PSS run](run-42317376618/README.md) observed two known handle values and normal cleanup in a never-resumed LPAC child. These are different processes and executables: neither shows that the PSS-observed child reached the initializers. The earlier real byte-worker run remains incomplete and receives no confinement credit. None of these results establishes a cause.

## First: join PSS and initializer observations in one no-data lifetime

The highest-value next slice is a **single fixed no-data child** that first undergoes the reviewed PSS inspection while suspended and then, only if every mandatory pre-resume check succeeds, runs the same fixed initialization sequence. This associates both observations with one retained process lifetime; it does not establish complete environment equivalence or prove why an API returned a code.

- Use a fresh disposable Windows runner with no Writ mount, Writ session, policy pipe, fixture bytes or protected worker. The observer accepts no caller-selected executable, process, data, handle or destination. The fixed initialization child receives only its private report pipe; create an excluded synthetic event for a numeric-value negative control but do not inherit it. There is no general endpoint or actor admission.
- Reuse the unchanged zero-capability canary LPAC launch checks, WFP controls and separately budgeted observer design from the [LPAC PSS plan](pss-lpac-feasibility-design.md), including the explicit breakaway and membership checks. The child has a different executable, package, inherited handles and lifetime from the byte worker. Prefix generic launcher output as diagnostic only.
- Before resume, bind the PSS capture to the retained process handle, PID and creation time; extend the existing two-fixture-only PSS classifier with a separately tested fixed one-pipe case and require the exact one expected report-pipe value, absence of the excluded **numeric** value, completed bounded walk and stable counts, and a positive object comparison with the retained parent pipe. Any extra entry, missing API, count mismatch, failed readback, process-identity mismatch, invalid report, unverified cleanup or timeout is incomplete. The PSS table is a pre-resume snapshot only: the loader or initializer may create or change handles later, so it cannot establish the handle set or absence of alternate paths during initialization. PSS values do not by themselves prove provenance or the absence of an object under another handle. Free and check the PSS snapshot and marker, then close and check the parent's matching pipe writer before resuming; failure means do not resume. The act of snapshotting may itself perturb the diagnostic and has not been shown inert.
- Resume the retained original thread exactly once and require `ResumeThread` to return a previous suspend count of exactly 1; the existing `writ_worker_resume` helper only checks for an API error and cannot alone establish that transition. A return of 0, greater than 1 or an API failure is incomplete; do not retry the resume. Record fixed-size stage/result data for one `WSAStartup` call and direct return, and the system32 USER32/OLE32 loads, including immediate load errors, cleanup status and target-module state before each load. No sockets, clipboard access, COM activation, network traffic probe or data input is needed. Require the same retained child to exit successfully within the deadline and exactly one complete fixed-size report on the positively matched pipe, with no trailing bytes; any bad exit, missing/late/truncated/extra report, pipe or cleanup failure, or module already loaded before its observed load remains incomplete. Initializer errors remain errors, not access denials.
- Run same-runner ordinary no-data initializer controls before and after; repeat the LPAC observation at least twice on separate fresh processes, retaining each PID/creation time and cleanup result. Stop all further cases if any required cleanup is unverified. If useful, add a separate same-profile no-PSS initializer arm to look for gross snapshot perturbation; this is another process and remains exploratory. Preserve raw observations, repetition order and all failures, rather than turning repetition into a qualification claim.

The child is never admitted to data. Its supplied environment is a trusted launcher input; a child self-report after resume would be a weaker, potentially perturbing observation, not an independent pre-resume readback. Do not log environment contents, PEB data, dumps or unrelated machine information. If a future separate synthetic self-report is explored, require a reviewed bounded parser and retain its distinct timing and trust limitations.

## Then: exploratory capability and mitigation neighbors

Only after the first slice is source-reviewed and its result retained, a separately reviewed no-data-only test harness can vary one configured factor at a time. Its launch machinery must not change the canary worker or policy implementation. Use the same fixed synthetic child, verified process/job/token facts and owned package-scoped WFP state, with no data capability, no Writ session and no protected process. Where the platform permits, create one disposable package for sequential diagnostic variants and retain its exact identity within that trial; each process still has its own PID, creation time, job and report pipe. If the package cannot be reused safely, keep the varying package as an explicit uncontrolled difference and mark the comparison inconclusive.

| Arm | Capability SIDs | Win32k system calls |
| --- | --- | --- |
| A | none | disabled |
| B | only enabled `registryRead` | disabled |
| C | none | enabled |
| D | only enabled `registryRead` | enabled |

Compare A/B and C/D for the configured capability change, and A/C and B/D for the configured mitigation change. Run in counterbalanced repeat order, such as A B D C / C D B A, with ordinary controls bracketing the sequence. Record exact source/binary/runner, actual token capability and group/privilege sets, low-integrity and LPAC checks, job/child/UI/mitigation readbacks, package, process lifetime, handle snapshot and original configured environment input; record unknowns explicitly. Compare configured job limits, not volatile job counters. If a change induces any unplanned observed token, job, handle or other difference, or any required readback is unavailable, the affected pair is inconclusive. The pre-resume full environment remains independently unverified, so **all such pairs are exploratory/inconclusive for strict one-factor equivalence**. Package caches, registry state, library/provider startup and background OS activity can also affect sequential observations; counterbalancing cannot rule them out.

An optional separate WFP-on/off arm holds the A launch settings fixed, repeats the states in alternating order and changes only the dedicated package's owned dynamic filters **after the preceding no-data child has exited**. Verify the four owned filters and their package conditions before on phases, and verify those exact IDs absent after closing the owned session for off phases. Never remove a filter belonging to another component, change global firewall settings or use a data-bearing child. No packet or egress test is implied. A WFP difference is still exploratory and does not establish why initialization behaved differently.

## Required implementation and execution gates

Keep any new launch variations in a standalone diagnostic-only executable. It must not accept input bytes, mount a volume, receive Writ session or policy authority, alter the real worker's token/mitigation/job, or introduce a native policy engine. `writ_worker_create` currently hard-codes a fresh package and zero-capability/Win32k-disabled profile; a same-package factorial harness would need new scoped diagnostic machinery rather than silently changing the existing launcher. If verified construction is unavailable, stop the affected arm rather than substituting a broader or partially checked profile.

Require synthetic tests for malformed/truncated/extra PSS reports, mismatched expected values, token or mitigation drift, missing readbacks, timeouts, failed child retirement and every owned-resource cleanup failure. Distinguish pure classifier tests from adapter-level fault injection; the latter remains a known gap in the current native diagnostics. Require separate independent source/workflow review before an isolated exact-ref dispatch. A job must build and hash the exact source and binaries, run named synthetic tests, enforce a bounded supervisor and retain logs and failures. Close only owned PSS marker/snapshot, process/thread/job, handles, WFP sessions/filters, private image and package, and verify cleanup after the child exits; when the shared launcher erases state or the observer is killed, report cleanup unverified and rely on disposal only as fallback. PSS kernel-internal allocation and abrupt-parent behavior are not proven bounded by the in-process limits.

The most a future result can say is that a specific no-data child with recorded checks produced particular raw API results under the observed conditions. No result here changes the real strict LPAC failure, proves a Windows root cause, establishes complete environment identity or earns byte-worker confinement or host-qualification credit.

## First-slice implementation status

The source now includes a fixed observer, ordinary positive-control executable,
one-pipe table and progress classifiers, a shared exact-report/EOF reader,
and a fixed ordinary/LPAC/LPAC/ordinary workflow sequence. No capability,
Win32k or WFP factor variation is implemented. The workflow tests the pipe
reader with Windows synthetic complete, truncated, trailing-byte and open-writer
cases before running observations; those Windows tests and the observer have
not been executed. Portable tests cover table and progress classification only;
native adapter API/cleanup fault injection remains unimplemented.

The script's build/log paths use the trusted GitHub hosted runner's
`RUNNER_TEMP`; a standalone caller can choose this variable, so fixed path
selection is a controlled-workflow property, not a property of arbitrary script
invocation. The native observer and control accept no caller-selected targets.
A timeout or unverified cleanup stops the fixed sequence. PSS covers only the
pre-resume snapshot and supplies no proof of later handles or environment.
