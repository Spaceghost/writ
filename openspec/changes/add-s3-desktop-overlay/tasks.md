## 1. Product implementation

- [x] 1.1 Add shared Bend desktop transfer, provenance and version decisions.
- [x] 1.2 Add S3-compatible connections and conditional durable catalog publication.
- [x] 1.3 Add the desktop connection, file, policy, history and activity interface.
- [ ] 1.4 Connect Linux FUSE and Windows Cloud Files to real multi-file workspaces.
- [x] 1.5 Package the app with the existing reproducible desktop release pathway.

## 2. Acceptance

- [x] 2.1 Exercise real admitted and denied S3 transfers and preserved provenance.
- [x] 2.2 Exercise metadata browsing, native edits, conflicts, failure and restart.
- [x] 2.3 Exercise the app interface and installer on the supported platforms.
- [x] 2.4 Pass Bend, native, proof, source manifest and strict OpenSpec checks.
- [x] 2.5 Publish and anonymously verify complete app packages.

Implementation and native Linux/Windows S3, browser and package evidence are in
`verification/s3-desktop-overlay/`. Task 1.4 remains open: this app uses real
ordinary working files, not remote OS placeholders. Preview.4's Windows/Linux
installers and portable packages pass anonymous download verification. Proof checks do not
claim a new independent Lean kernel verdict or GPU execution.
