# Task 2: verify and review the native evidence

Require a successful fresh run of all three native Genode boots at the candidate
revision. Verify the downloaded ZIP against GitHub's artifact digest, retain
serial transcripts and exact environment/configuration/hash files, and record
timing and allocation counters. Distinguish the complete 3072-check corpus from
the earlier failed partial run and historical smaller suites.

Update the native verification record, README and NM001/NM007 traceability
without completing broader host tasks. Have an independent reviewer inspect
the final evidence and scope. Validate changed documentation with OpenSpec
1.16.0. Native execution already includes ordinary Bend proof checks; no Lean
kernel verdict, GPU result, machine-code Bend port or complete protected-host
claim follows from this change.
