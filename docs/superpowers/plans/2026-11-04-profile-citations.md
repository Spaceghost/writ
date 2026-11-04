# Plan: Runtime host profile, citations from the host changes (task 2.3, first half)

Spec: `openspec/changes/add-bend-runtime-host-profile/` task 2.3: "Document the profile's role in the Genode, Windows, Drift kernel, unikernel, and freestanding changes and update their runtime tasks to cite it; leave those tasks unchecked." The profile is `scripts/runtime-profile/` (inventory, allow lists, `check-binary.sh`), `docs/BEND-RUNTIME.md`, and the per-host record `verification/runtime-profile-hosts.md`. This lane does the three changes no live lane is editing: `add-windows-host`, `add-drift-kernel-host`, `add-freestanding-bend-runtime`. The Genode and unikernel halves follow when the `genode-base-hw` and `unikraft-twins` lanes land; box 2.3 stays unchecked until then.

## Global Constraints

- Text-only lane. Touch only `openspec/changes/add-windows-host/`, `openspec/changes/add-drift-kernel-host/`, `openspec/changes/add-freestanding-bend-runtime/` (design.md and tasks.md only; never a spec delta), and `openspec/changes/add-bend-runtime-host-profile/tasks.md` (a note under 2.3 listing which changes now cite the profile and which wait; the box stays `[ ]`). No requirement text changes; no box checked anywhere.
- Validate with `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive` and record the count. No manifest, no push, one commit per task.
- Append one line per step to `docs/superpowers/records/2026-11-04-profile-citations/activity.log` (tab-separated time, role, text); report at `docs/superpowers/records/2026-11-04-profile-citations/task-1-report.md`; `git add -A docs/superpowers/records/2026-11-04-profile-citations` with each commit.

### Task 1: The three citations

For each of the three changes: add one short paragraph to `design.md` (under its runtime or host-binding section) saying what the runtime host profile is for that target (the monitor profile's allow lists are the contract for what a monitor binary may link and call; `check-binary.sh` is the check; the per-host record is where its corpus run belongs), citing `docs/BEND-RUNTIME.md`, `scripts/runtime-profile/check-binary.sh`, and `verification/runtime-profile-hosts.md` by path; and in `tasks.md`, append to the runtime-related task line(s) a parenthetical "(cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)" without checking anything. Read each change's design first so the paragraph matches what that target actually binds (Windows: WinFsp/broker product per docs/PLATFORMS.md; Drift: drivers, not the kernel's authority boundary; freestanding: nelibc as a candidate libc, no host libc). Then add the 2.3 note in the profile change's tasks.md: Windows, Drift kernel, freestanding cited on 2026-11-04; Genode and unikernel wait for the live lanes.

Acceptance: three design paragraphs and their task citations in place; no box changed; OpenSpec strict passes; the report lists every edited line.
