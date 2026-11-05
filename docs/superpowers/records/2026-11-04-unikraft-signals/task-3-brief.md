### Task 3: Record the adoption and check box 2.3

Update `docs/UNIKERNELS.md`: the trust inventory lists `lib/posix-process` with signals as an experimental library in every image and the build flag; the fault section states the message now appears, that the image still ends in a Unikraft crash with the hook's value 253, and that arena exhaustion remains a crash without a message (the recorded limit, with the file that shows it). Update matrix row E4 in `verification/unikernel-matrix-unikraft.md`, the UL-006 row in `openspec/traceability/unikernel-library-runtime.md` (message: executed; exhaustion: limit), and check box 2.3 in `tasks.md` citing the evidence files. Run `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive` and `bend Tests.bend` on Linux; record both in the report.

Acceptance: the inventory, matrix, traceability, and tasks box agree with the evidence files; OpenSpec strict passes; the suite is 782.
