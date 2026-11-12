# Directory and S3-compatible desktop sync

Branch: `lane/directory-sync`, initially based on the Windows shell lane at
`8ac30c4`; integrate its reviewed fixes before delivery.

The user explicitly requested multiple-file/folder syncing and remote/cloud
syncing, selected S3-compatible storage including Cloudflare R2 first, and wants
OneDrive after its application credentials become available. The one-file
preview and native shell alone do not complete this task.

## Design constraints

- One Bend implementation owns per-file reconciliation, conflict decisions,
  expected-base checks, streamed artifact verification and commit admission.
- Native Windows bindings translate directory/Cloud Files observations, hold
  exact file handles, perform admitted effects and implement bounded S3 HTTP
  transport. The desktop app keeps credentials in Windows Credential Manager.
- Store immutable content and a versioned directory manifest under a selected
  remote prefix. Publish the manifest using S3 conditional writes; never retry
  an unconditional overwrite after a conflict. Preserve local recovery bytes
  before replacement/deletion, and preserve both sides of concurrent edits.
- Directory scans and downloads reject path escapes, reparse/symlink traversal,
  ambiguous Windows names and unsupported filesystem objects. State and queues
  are bounded; capacity/network/credential failures retain local data.
- Support nested folders, creation, edits, rename/delete reconciliation,
  offline edits, reconnect, new-client hydration, and visible conflict/recovery.
- Complete native Windows and real S3-compatible endpoint tests, including
  competing clients and failures. Distinguish protocol/server tests from actual
  Cloudflare R2 evidence. No protected-host or whole-system proof claim.

## Working increments

1. Extend shared artifact verification to bounded streaming without weakening
   existing digest/commit gates. Add independent SHA-256 vectors and boundary tests.
2. Implement a Bend directory reconciliation protocol with explicit transaction
   phases and conflict/namespace tests.
3. Add native directory and conditional S3 storage, then the app connection UI
   and credential lifecycle. Use public disposable fixtures for acceptance.
4. Validate existing and new Bend/native suites, ordinary proofs, strict
   OpenSpec, review and source manifest; integrate and push to master.
5. Publish verified packages and update spacegho.st/writ with actual capabilities,
   setup instructions and evidence. OneDrive remains a later authenticated adapter.
