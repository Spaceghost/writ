# Plan: Genode component, host-layer memory milestone

Spec: `openspec/changes/add-genode-bend-component/` (GB-001 through GB-011; tasks 1.1, 1.3, 1.4). Prior evidence: `verification/genode-runtime-rows-base-linux.md` (the two blockers with source citations), `verification/genode-bend-hello-base-linux.txt`, `verification/genode-pins.txt`, `scripts/genode/writ_bend_hello/`, `docs/GENODE.md` ("Runtime rows on base-linux, 2026-11"). Read the rows file's memory and faults sections and its "Authored non-Bend files" paragraph first.

## Global Constraints

- Toolchain and tree as the pins record: Genode 26.08 at `d18ee9e9…`, the prebuilt 25.05 toolchain, nixpkgs expect, host clang-23 for the generated C, everything under `../writ-genode/`. No root.
- The generated C is never edited. The Bend runtime is never patched.
- GB-006 allows exactly one authored C++ unit in the monitor component: the shim. The memory host layer is part of that shim. It lives under `hosts/genode/shim/` in this repository as source, is copied into the Genode repo build (`../writ-genode/writ-repo/`) by the target.mk, and `hosts/genode/INVENTORY.md` lists its files, exported symbols, sessions used, and reviewer. No policy decision lives in it. Headers say it is host binding code, not Writ policy.
- `mprotect` is never a no-op. A guard region must be unmapped memory that faults.
- Evidence under `verification/` with exact commands and log lines; base-linux is Genode-on-Linux, never native; CPU only.
- Do not modify any `.bend` file. Touch only `hosts/genode/`, `scripts/genode/`, `verification/`, `docs/GENODE.md`, and the change's `tasks.md` (boxes only with evidence). Do not push. Commit at each acceptance point. Write the SDD report file early.
- Time-box each task at about three hours; a recorded stall is a valid outcome.

### Task 1: A lazily populated reservation with a real guard, as a C probe

Design and prove the mechanism on a plain-C Genode component before touching the Bend build.

1. Implement, in C++ under `hosts/genode/shim/` (one translation unit, `extern "C"` entry points), replacements for `mmap`, `munmap`, and `mprotect` that apply only to anonymous `MAP_PRIVATE|MAP_ANON` requests of at least 1 GiB (the runtime's heap and stack reservations); everything else forwards to Genode's libc. For a qualifying `mmap`: create a managed dataspace via `Rm_connection` / `Region_map` of the requested size, attach it into the component's address space, and install a fault handler that, on first touch of a page range, allocates a RAM dataspace chunk (for example 2 MiB) from the component's own PD and attaches it at the faulting offset. This gives `MAP_NORESERVE` semantics: RAM is charged only when touched. For `mprotect(addr, len, PROT_NONE)` inside a managed region: detach any populated chunk overlapping the range and mark the range as a guard so the fault handler refuses to populate it; a touch there is an unresolvable fault and the component dies (the fault substitute GB-003 accepts). For `munmap`: detach and free.
2. Cite the Genode 26.08 headers you rely on (`region_map/client.h`, `rm_session/connection.h`, `base/attached_ram_dataspace.h`, the fault-handler signal API) with file paths in the evidence.
3. Probe: `hosts/genode/probes/reservation/` with a C `main` that mmaps 8 GiB anonymous, touches one page at the start and one near the end, calls `mprotect` on a 16 KiB window to PROT_NONE, touches inside it (expect death), and, in a second run without the guard touch, exits 0. Run both under init on base-linux with a 256M quota and record the logs, the RAM quota actually consumed (from init's reporting or `Pd_session::used_ram`), and the component death on the guard touch.

Acceptance: an 8 GiB anonymous reservation succeeds under a 256M quota, touched pages are charged lazily, and a guard-page touch kills the component with the parent logging the fault. Evidence: `verification/genode-reservation-probe-base-linux.txt`.

### Task 2: The Bend hello reaches `main`

Link the Task 1 translation unit into `writ_bend_hello` (target.mk; symbol interposition over libc's `mmap`/`mprotect`/`munmap`, or the libc's documented override mechanism if symbol order does not win; record which and why). Keep `-DMAP_NORESERVE=0` only if still needed and say so. Add the `vfs_pipe` mount and libc `pipe` attribute the event-loop row requires. Run under init at 256M. Expected: `hi` in the log and exit value 0. Record every error on the way with its fix. Evidence: `verification/genode-bend-hello-base-linux.txt` (append a dated section).

Acceptance: the unmodified generated hello C prints `hi` under init on base-linux with exit value 0, or a recorded stopping point with the exact symbol and reason.

### Task 3: Corpus and fault row through the Bend program

Build `Tests.bend` and the four examples as components with the same configuration (quota as needed, recorded). Capture logs and compare line for line with the Linux single-lane records (`verification/runtime-profile-parity-1.txt`). Then run `scripts/runtime-profile/Overflow.bend` as a component and record what happens: the runtime's own fault message cannot appear on base-linux (the host handler pre-empts it per the rows file); record whether the component dies and whether the parent logs it; that is the GB-003 substitute. Update `verification/genode-runtime-rows-base-linux.md`: memory rows now `supplied (host layer)`, faults `substituted` or `missing` per observation, event loop `supplied`, with provenance "Bend program". Update the `docs/GENODE.md` section. Check `tasks.md` 1.1 (hello printed), 1.3 (only if the fault substitute was executed through the Bend program), 1.4 (only if parity matched). Write `hosts/genode/INVENTORY.md`.

Acceptance: 764 PASS lines and the final line in the component log, or a recorded stopping point; rows updated with provenance; inventory written; boxes match evidence.
