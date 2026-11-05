# Task 2 report: appliance rules applied to the library image (3.2)

Status: DONE_WITH_CONCERNS

Files: `verification/unikernel-appliance-rules.md` (new); `docs/UNIKERNELS.md` (one bullet
linking to it, after "Host code"); `openspec/changes/add-unikernel-library-runtime/tasks.md`
(box 3.2 checked, with a note citing the file). No script, host C, Bend, Unikraft or
traceability change. OpenSpec 1.16.0 `validate --all --strict --no-interactive`: 44 passed, 0 failed.

## The ten rows

| UA | Title (quoted) | Result | Gap, in short |
| --- | --- | --- | --- |
| UA-001 | "The image contains only the monitor" | partly | No shell, login, debugger or package tooling in the 55-object link; no initrd or filesystem. But the only monitor image fails the profile check (Unikraft.log/put/take rows), so "the monitor passes the runtime profile's binary check" is not met. execve and ukbinfmt are linked (selected by the signal library), with no loader registered (review-only). |
| UA-002 | "Builds are reproducible and pinned" | not met | Inputs are pinned, but the drill's hash differs (embedded build time). No deployment and no pinned build container. |
| UA-003 | "The corpus runs inside the image" | met for the corpus | 782 PASS on one lane, CPU, under TCG and KVM; the four examples (TCG). The "638 count" predates the corpus. |
| UA-004 | "The address space is not a worker boundary" | not met | No worker request path, so no denial is recorded; no worker domain; the subject is a build-time word. |
| UA-005 | "One authenticated ingress" | not met | One ingress (COM2 channel) and no socket library, but the channel is not authenticated, there is no store connection, and no endpoint scan was run. QEMU's default card is attached (iPXE seen) but has no driver in the image. |
| UA-006 | "State lives outside the image" | not met | No store; the state is the compiled-in SYNTHETIC Scenario. |
| UA-007 | "Rebuild is drilled and timed" | partly | The rebuild drill ran and was timed. No running appliance, no store, no reconciliation; run once only. |
| UA-008 | "Clock and entropy are checked at boot" | not met | No boot clock check; host.c checks only inside sleep (not exercised); ukrandom is not set; no challenge issuance. |
| UA-009 | "The trusted base is stated" | met (document) | The statement names QEMU 11.1.2, host kernel 7.2.9-1-MANJARO, SeaBIOS 1.17.0-2-2 (and iPXE), and Unikraft 0.21.0 with all 55 objects. The Linux claim is scoped to the guest. The drill is not the reconciliation drill. |
| UA-010 | "Evidence is separated by execution environment" | met for what exists | TCG, KVM and linuxu are in separate files; the GPU line is the CPU fallback. No physical deployment exists. |

## Rebuild drill

Commands (from the worktree root, Bend 2.0.39 on PATH, BEND_NO_TELEMETRY=1):

    hosts/unikraft/scripts/mkapp.sh drillhello
    bend scripts/unikernel/Hello.bend -o $W/drillhello/gen/hello.c
    hosts/unikraft/scripts/build.sh drillhello hello
    hosts/unikraft/scripts/check-image.sh drillhello drill-hello hello $W/sigeffects/hello-ref.txt 33 "" 60 1024
    hosts/unikraft/scripts/run.sh drillhello drill-kvm-hello hello "+RTS --threads 1 --gpu off" 60 1024 "" kvm
    WRIT_NO_BOOT=1 hosts/unikraft/scripts/check-image.sh drillhello drill-kvm-hello hello $W/sigeffects/hello-ref.txt 33 "" 60 1024

Before the build, these were rechecked against the pins: the Unikraft and lib-musl commits
(clean trees), kraft's sha256, the toolchain versions, the Kraftfile and build.sh hashes.
`hello.c` was 260b70a3 (= pins); the musl tarball 7d5b0b60 (= pins).

Elapsed: `mkapp.sh` 0.03 s, emit 0.45 s, clean build 68.2 s (first attempt, no fetch
failure), **68.7 s from the new set to the image**. TCG boot 0.3 s, KVM boot 1.1 s (QEMU
wall). Load average 27 to 47.

Hash comparison: image f8f49e7d... against the recorded d0421dfb... (sigeffects/hello-qemu),
**different**. `.dbg` 1eff1720... against d5780782..., different. What was compared instead:
- The 6 differing bytes of the booted image all lie in the 25-byte build-time string in
  `.uk_libinfo`. With it masked, the images are byte-identical (both 85b8fa40...).
- Sizes equal (1193040; `.dbg` 12364736). `size -A` identical; `.text`, `.rodata`, `.data` identical.
- `nm` inventory identical (4523 symbols). check-binary.sh identical (IO.print, PASS, exit 0).
  Link set identical (55 objects). `.config` differs only in CONFIG_UK_APP.
- One boot each, TCG and KVM: `hi`, QEMU 33, check-image.sh PASS. The program lines equal
  the recorded boot's.
- The `.dbg` files differ in 752218 bytes, from the build paths in their debug info.

## Concerns

1. The dispatch asked the trusted-base statement to name "what is outside the base (QEMU,
   the host kernel, the harness scripts)". UA-009 requires the hypervisor and host kernel to
   be named as trusted, and forbids describing the host as removed from the trust boundary.
   So the file lists QEMU, the host kernel and the firmware as *outside the image but
   trusted*. Only the harness and build scripts are listed as outside both the image and
   the guest; they are trusted only for their verdicts. Please confirm this reading.
2. Box 3.2 is checked because every row has evidence or a quoted gap and the drill ran, as
   the box asks. UL-008 itself remains unmet: five rows are gaps and two are partial. The
   traceability row for UL-008 still says "none" and "tasks.md 3.2 open". It is Task 3's to
   update; it was not touched here.
3. Task 1's fix round 2 (e944b22) landed at 01:34:34Z, after both drill boots and while this
   task was running, and changed `env.sh`, `check-image.sh` and `check-fault.sh`. Both drill
   captures were rechecked under e944b22 (PASS, dropped 0). The KVM cites were also moved to
   the renamed section "Result (KVM), strict checks before the fragment rule" plus "Fix round 2".
4. Observation for a follow-up: every boot runs with QEMU's default network card (iPXE ROM at
   00:03.0 in the capture); `run.sh` does not pass `-nic none`. The image has no driver for
   it. This matters to UA-005's scan scenario.
5. A likely route to UA-002, `CONFIG_LIBUKLIBID_INFO_COMPILEDATE`, was not tried (review-only;
   it would change the template and every image).
6. The drill's set `$W/drillhello` and `$W/drillhello-unikraft` are left in the workspace
   (outside the tree).
