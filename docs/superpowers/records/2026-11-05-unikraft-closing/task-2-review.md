# Task 2 review: appliance rules applied to the library image (3.2)

Verdict 1, spec compliance: APPROVED
Verdict 2, record quality: APPROVED

## Findings (all minor, none blocking)

1. verification/unikernel-appliance-rules.md, UA-009 row and trusted-base statement: the row is labelled "met by the statement below", but the spec's scenario precondition is "a passing drill and corpus under KVM". The row itself admits the drill is the rebuild drill, not UA-007's reconciliation drill. The caveat is stated, so the label is defensible. Fix (optional): label "met (document); scenario precondition partly met".
2. Same file, UA-003 row, "A primitive is missing": the spec says the mismatch is "recorded as a failed qualification of that unikernel". The row says it was recorded as a missing fault message, then the library was adopted as a pin. The citation is accurate but does not use the spec's phrase. Fix (optional): add the phrase "failed qualification" and say whether the earlier fault record used it.
3. Same file, trusted-base statement, "marked EXPERIMENTAL at lib/posix-process/Config.uk:78": in the pinned tree, line 78 is `config LIBPOSIX_PROCESS_SIGNAL` and the EXPERIMENTAL prompt string is on line 79. Fix: cite :78-79.

## Verified

- Titles: all ten UA titles match the spec headings (spec.md lines 11, 27, 43, 59, 75, 91, 107, 123, 139, 155) exactly.
- Quoted gap phrases: 19 phrases grepped against spec.md, each found once. The one exception, "build container pinned", is correctly attributed to design.md lines 33 and 98 ("the appliance design").
- Citations opened: unikernel-kvm.txt (headings "Machine", "Result (KVM), strict checks before the fragment rule", "Same-session TCG controls", "Fix round", "Fix round 2" all exist; 782 and 3 of 3 at lines 66 and 148); unikernel-binary-check.txt ("Signals rerun" line 6, "History" line 114); unikernel-channel-qemu.txt ("Binary check (UL-003, signals present)" line 180, "Result (signals present)" line 28, rows `Unikraft.log put take` and "outside the monitor profile"); unikernel-corpus-qemu.txt ("Result (signals present)" line 32, "not GPU evidence"); unikernel-effects-qemu.txt ("Builds (set sigeffects" line 49); unikernel-lanes-qemu.txt ("Stopping point" line 249); docs/UNIKERNELS.md ("Port status", Ingress line 119); INVENTORY.md ("Monitor and client", "Image hashes are per build"); Channel.md ("Request record", "Subject"); tasks.md 2.2 note on the 638 count. The "host-symbol surface was not checked" quote was not opened; it is a low-risk quote.
- Drill: commands, per-step times (0.03, 0.45, 68.2, 68.7 s), both hashes, and the comparison table are recorded. I reran the comparison on the retained images: sha256 d0421dfb vs f8f49e7d; `cmp -l` gives exactly 6 differing bytes, at offsets 1116878 to 1116887. This backs the "identical except the 25-byte build time" claim, with the masked hash, the sizes, the nm list and the binary check recorded alongside. The drill does not hide the hash mismatch; UA-002 is "not met".
- Trusted-base statement: the link set of the drill build (`dbg.cmd`) has 55 objects, and every one is named in the statement (checked mechanically). It includes the experimental signal library (`LIBPOSIX_PROCESS_SIGNAL`, with `libukbinfmt` and execve selected by it), and the `-include uk/config.h` build flag with its rationale. Hosts, firmware and harness are separated as the controller ruled.
- Scope: commit 102c4c7 touches docs/UNIKERNELS.md (one link bullet), tasks.md (box 3.2 plus a note citing the file), and the new rules file. Nothing else.
- Honesty: the file says repeatedly that the appliance change is not implemented. Labels: 3 met (qualified), 2 partly, 5 not met. Each label matches its requirement text on reading. The failed monitor-profile check (UA-001) and the missing authentication (UA-005) are preserved, not softened.
