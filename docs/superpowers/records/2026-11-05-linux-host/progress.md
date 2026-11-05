# SDD ledger — plan: docs/superpowers/plans/2026-11-05-linux-host.md
Branch: lane/linux-host

Conflict scan: Task 1 is Bend (hosts/linux/monitor/LinuxHost.bend and tests, one Tests.bend registration, no law); Tasks 2-4 are C under contrib/native-hosts/linux/ (broker.c, launch.c) plus evidence; Task 5 records and the CI job. The FUSE canary stays byte-identical. Rulings: unprivileged controls run on this host, privileged ones in the Linux CI VM, each row says which; no sudo. Cross-lane: no count pins.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (60dc1fe): 1511 checks (+83), 31 mutants killed, Linux vector replay cmp-identical (37816dd7…), no law change. Rulings: Landlock rights and no_new_privs map to a control in Task 3 (recorded as a gap now); box 1.1 is unchecked until Task 3 lands the native pins (the controller will flip it at merge if Task 3 does); admission through the broker Barrier frame only is right; the effect rule is enforced by the module never building an Admitted step and said so, not by the types. Reviewer dispatched.
Task 1: review NEEDS_FIXES both axes (box 1.1 checked against the ruling; a Barrier fact is not bound to the session it admits, a foreign-subject fact admitted session 2; StaleLaunch across a restart untested; inventory incomplete; six minor). Fix round 1 dispatched.
Task 1: fix round 1 done (8dafe74): Barrier bound to its session (SessionMismatch), restart checks, inventory complete, box 1.1 unchecked; 1519 checks, 38 mutants killed. Scoped re-review dispatched.
Task 1: complete (re-review ALL CLOSED; 1519 checks; two optional nits carried to Task 5).
Task 2: dispatched implementer (native broker and authenticated worker session)
