# SDD ledger — plan: docs/superpowers/plans/2026-11-04-binding-gaps.md
Branch: lane/binding-gaps
Base: dce0b0c
Preflight: three lanes touch disjoint files (hosts/unikraft + scripts/unikernel + verification/unikernel-*; hosts/genode + scripts/genode + verification/genode-*; HostBinding*.bend + its records). Ruling: host adapter code lives under hosts/<target>/ with an INVENTORY.md (new convention, flagged for Spaceghost); VERIFICATION.md and the manifest are edited only by binding-gaps, others leave them for integration.
Task 1: implementer DONE (commit 71edf5c; 769 checks, 41 vectors). Review dispatched.
Task 1: complete (commits dce0b0c..71edf5c, review clean). Minor (deferred to Task 3): GA-009 row says 40 vectors (now 41); host obligation wording (withdraw rerouted domain endpoints at reconfiguration); fixture-domain sentence; optional named helper.
Task 2: implementer DONE (commit c058ed5; 780 checks). Ruling: clause (b) scoped to live (current-generation) objects is accepted — destroyed objects legitimately lose their copy records; the two hand-built fixtures that violated it were corrected and their old shapes kept as negative fixtures. Review dispatched.
Task 2: complete (commits 71edf5c..c058ed5, review clean). Minor (deferred to Task 3): forged_holder comment (minter now names W); generations_copy comment; single_minter cost comment.
Task 3: complete (commit d5b4fc9; records at 780/41, manifest clean). All plan tasks complete; final whole-branch review dispatched.
Final review: ready after fixes (records/comments). Ruling: one fix wave for I1 (bend_source_lines 8143), M2-M6 (VERIFICATION wording; OpenSpec paragraph; HOST OBLIGATION wording in code and traceability; single_minter cost comment; two extra tests for onward delegate and close by a rerouted W), plus the named helper acts_for_owner at both sites. Declined-to-judge items recorded for a later pass (doubly-routed domains; restored routes; intermediate rerouted; stale-holding revoke).
Final fix wave: commit a4cbe1d (782 checks). Scoped re-review dispatched.
Final fix wave re-review: all addressed. Finishing: merging lane/binding-gaps into master.
