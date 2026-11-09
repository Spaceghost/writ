# Proposed local supervisor and synthetic Copy revocation

The proposed local profile makes the trusted supervisor, its protected
administrative channels, separate source and destination authority, subject
binding, trusted clock and recovery obligations explicit. These are proposed
requirements, not an implemented or qualified host. The bootstrap still needs
real channel authentication and non-transfer, an authority owner, a single
gated observation path and replay-safe recovery.

The [two synthetic tests](../../LocalSupervisorTests.bend) use the exact canary
Copy plan and the existing `MountAuthority.descriptor` and `DataOS` commit. After
that commit, independently revoking the source or destination approval denies
fresh checks of the same descriptor; the exact cached pre-revocation projections
still resolve. Retrying against the returned committed session and ledger is
rejected with both unchanged, while the original intent is examined separately.
The fixture is Free with zero charge: this trace does not establish replay of a
nonzero payment. It does not call `Mount.dispatch`, observe FUSE bytes, or
establish native authentication.

## Verification

- [Bend full suite](tests-bend.txt): 2,883 PASS lines and `ALL LIBRARY TESTS
  PASSED`. [Generated Node](tests-node.txt) produced byte-identical output.
- [Generated native CPU suite](tests-native.txt) passed with byte-identical
  output, compiled at `-O0` and run with one CPU thread and GPU disabled.
- [Ordinary proof](proof.txt) and [pinned BendTT verdict](verdict.txt) passed;
  the [`/bin/false` negative control](negative.txt) failed as expected. This
  adds no new proven law.
- [OpenSpec strict](openspec.txt) passed 45 items. Initial runs failed on
  [overlong requirements](openspec-initial.txt), then [missing scenarios](openspec-second.txt);
  the requirements were split and scenarios supplied. This is structural
  validation, not implementation or host qualification.

The exact tested Bend sources are recorded in [the input manifest](bend-input-sha256.txt).
Commands, limits and results are recorded in [build commands](build-commands.txt).
The repository-wide source manifest separately describes the delivered tree.
No native identity probe, FUSE mount, VM, live authority bridge, GPU test,
rollback-resistant recovery or protected host acceptance is claimed.
