# Appliance rules applied to the library image (task 3.2)

Recorded 2026-11-05 UTC (Unikraft closing lane, Task 2) on Linux x86_64 (Manjaro), no root.

This file holds task 3.2 of `openspec/changes/add-unikernel-library-runtime/`. That task
applies the appliance host's requirements UA-001 to UA-010
(`openspec/changes/add-unikernel-appliance-host/specs/unikernel-appliance-host/spec.md`) to
the Unikraft library image. **The appliance host change is not implemented, and this file
does not implement it.** No appliance image exists. The library image is the
`hosts/unikraft/app/` template built by `hosts/unikraft/scripts/build.sh` (Unikraft 0.21.0,
qemu/x86_64, posix signals present), the same template the corpus, examples, probes and
channel monitor were built from. Each row below gives either the evidence that meets the
requirement for that image or the gap, quoted in the requirement's own words.

How to read the cites. *Executed* means a build, boot or check was run, and the cite names
the evidence file and section that holds it. *Review-only* means the fact comes from
reading a configuration, source or symbol table, and nothing was run to exercise it.
`W` is the build workspace
(`/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel`). Nothing
built is in the tree.

Example. The rebuild drill below makes a fresh set with `mkapp.sh`, emits `hello.c` from
`scripts/unikernel/Hello.bend` with Bend 2.0.39, and does a clean build in 68.2 s. The new
image's sha256 is `f8f49e7d...`; the recorded one is `d0421dfb...`. The hashes differ, so
UA-002 is not met. Mask the one 25-byte build-time string, and the two booted images are
byte-identical; the drill image boots to `hi`, QEMU 33, under both TCG and KVM.

## Checklist

| UA | Requirement title (quoted) | Library image | Evidence (file, section) | Gap (the requirement's own words) |
| --- | --- | --- | --- | --- |
| UA-001 | "The image contains only the monitor" | partly | *Executed:* the image is one static ELF passed to QEMU as `-kernel`. No initrd and no filesystem image are given (every `run.sh` command line, e.g. `$W/drillhello/logs/run-drill-hello.log`, drill below). The drill build links 55 objects, listed under "Trusted-base statement" below and equal to the recorded hello build's link set. None of them is a shell, a remote login service, a debugger, or package tooling. The configuration has `CONFIG_LIBPOSIX_SOCKET`, `CONFIG_LIBUKNETDEV`, `CONFIG_LIBVFSCORE`, `CONFIG_LIBUKFS_RAMFS`, `CONFIG_LIBUKCPIO` and `CONFIG_LIBUK9P` all not set (`$W/drillhello-unikraft/.config.writ-bend_qemu-x86_64`, drill below). The `.dbg` with debug info is a separate file and is never booted. *Review-only:* Unikraft 0.21.0's `lib/` has no shell library. The symbols `getusershell`/`setusershell` are musl's `/etc/shells` reader, not a shell. The signal library selects `LIBPOSIX_PROCESS_EXECVE` and `LIBUKBINFMT`, so `execve` and `uk_binfmt_register` are linked. A grep of the pinned `lib/` finds no library outside `ukbinfmt` that registers a loader, and no loader is in the link. Not exercised. | "the monitor binary built under the monitor runtime profile": the library images are the corpus, the examples and probes, and the scaffolding channel monitor. The only monitor image, `sigchannel/monitor-qemu`, fails the profile check: its effect rows are `Unikraft.log Unikraft.put Unikraft.take`, "outside the monitor profile", checker exit 1 (verification/unikernel-binary-check.txt, "Signals rerun"; unikernel-channel-qemu.txt, "Binary check (UL-003, signals present)"). So "the monitor passes the runtime profile's binary check" is not met. Images whose only effect is `IO.print` pass (the same section). The check reads effect rows only: "the host-symbol surface was not checked". |
| UA-002 | "Builds are reproducible and pinned" | not met (inputs pinned; hash differs) | *Executed:* every input is pinned: Unikraft 7351f8b, lib-musl 5fed64e, the musl 1.2.3 tarball `7d5b0b60...`, kraft 0.12.16 `cd7ffa22...`, gcc 16.2.1, binutils 2.47, Bend 2.0.39, the Kraftfile `ea319440...` and `build.sh` `67ceb9d2...` (verification/unikernel-pins.txt; all rechecked for the drill, below). In the drill's clean rebuild, the hash differs from the recorded image. With the 25-byte build-time string masked, the two booted images are byte-identical, and their symbol inventory, sizes, binary-check output and boot output are equal (drill, "Comparison"). | "Two clean builds from the same pinned Writ source, Bend version, unikernel version, and build environment SHALL produce the same image hash": not met. The drill gave `f8f49e7d9f714e24...`; the record is `d0421dfbf5deb0d5...`. Unikraft embeds the build time (`lib/uklibid`, section `.uk_libinfo`). The `.dbg` files also differ in 752218 bytes (debug info carries the app-directory and worktree paths). "deployments SHALL name images by that hash": there is no deployment, and no stable hash to name images by. The build environment is this host, not a pinned container (the appliance design asks for "build container pinned"). *Review-only, not tried:* `CONFIG_LIBUKLIBID_INFO_COMPILEDATE=y` is set in the configuration and is the likely source of the date. |
| UA-003 | "The corpus runs inside the image" | met for the library corpus (one lane, CPU), with the count gap | *Executed:* `Tests.bend` prints 782 PASS lines and `ALL LIBRARY TESTS PASSED`, QEMU 33, with the program lines equal to the Linux single-lane reference. The four examples (`Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, `GpuExample.bend`) give empty diffs. Lane count 1 (`+RTS --threads 1 --gpu off`, `UKPLAT_CPU_MAXCOUNT=1`), QEMU TCG (verification/unikernel-corpus-qemu.txt, "Result (signals present)"). The corpus under KVM: 782 PASS, QEMU 33, 3 of 3 boots, and every capture passes check-corpus.sh under the shutdown fragment rule (verification/unikernel-kvm.txt, "Result (KVM), strict checks before the fragment rule", "Fix round", "Fix round 2"). The examples were not booted under KVM. "A primitive is missing": without the signal library the runtime had no alternate signal stack. That was recorded as a missing fault message (the fault record does not use the phrase "failed qualification"), not patched around. The library was then adopted as a pin (verification/unikernel-fault-qemu.txt, "Result"; unikernel-pins.txt, "Unikraft image configuration pins"). | "the 638 count matches": the corpus is now 782 checks, and the 638 count "predates the current corpus" (tasks.md 2.2). The comparison is against the 782-check reference. This is the library corpus image, not an appliance image. More lanes are open (tasks.md 2.4: "the corpus was not run on two lanes", verification/unikernel-lanes-qemu.txt, "Stopping point"). |
| UA-004 | "The address space is not a worker boundary" | not met (no worker path exists to deny) | *Review-only:* each image runs one Bend program, fixed at build time (`build.sh` copies one `gen/<probe>.c` to `app.c`). No image has a code input: no filesystem, no network driver, and no registered `execve` loader (UA-001 row). The channel monitor's frames carry 64-byte records only (`hosts/unikraft/effects/Channel.md`, "Request record"). None of this is a denial; it is the absence of a path. | "SHALL deny execution of requester-supplied or transformation code inside the image": no request asks for worker execution, so the "Worker execution is requested in the appliance" scenario has no instance and no denial is recorded. "worker confinement SHALL be provided by separate domains under the portable host contract": no worker domain exists for this target. The monitor's channel subject is "a build-time word, not a route" (docs/UNIKERNELS.md, "Port status", Ingress; Channel.md, "Subject"), so "with its subject bound by the host contract" is not met. |
| UA-005 | "One authenticated ingress" | not met | *Executed:* the channel monitor reads exactly one ingress, the Writ channel over COM2 (`CONFIG_LIBNS16550_COM2`, a Unix socket on the host). Accepted and Bend-denied round trips pass `check-channel.sh` (verification/unikernel-channel-qemu.txt, "Result (signals present)"). No listening-socket library is linked: `CONFIG_LIBPOSIX_SOCKET`, `CONFIG_LIBPOSIX_UNIXSOCKET` and `CONFIG_LIBUKNETDEV` are not set (drill configuration). The "general socket effect is linked" control, `Widened.bend` with `TCP.listen`, fails the binary check, exit 1 (verification/unikernel-binary-check.txt, "History", `bincheck/widened`). It was built before the signal library and not rerun since. *Observed:* every boot runs with QEMU's default network card (the drill capture shows iPXE at PCI 00:03.0 before Unikraft starts). The image has no driver for it. | "the host contract's authenticated session channel": the channel is not authenticated, and "whoever reaches the socket speaks as" the built-in subject (docs/UNIKERNELS.md, "Port status", Ingress). "plus its durable store connection": there is no store connection. The "Network scan of the appliance" scenario was not run: no endpoint enumeration exists. QEMU's default card was not removed (`-nic none` is not passed). The monitor image itself fails the monitor runtime profile's check (UA-001 row). |
| UA-006 | "State lives outside the image" | not met | *Review-only:* the image has no writable store. The monitor's state is the SYNTHETIC `examples/Scenario.bend` state, compiled in (`hosts/unikraft/INVENTORY.md`, "Monitor and client"). Each boot starts from it, and nothing written survives the boot (no disk, no filesystem: UA-001 row). | "Session, ledger, authority epochs, and sealed artifacts SHALL persist only through the durable publication store attached at boot": no store is attached and none of these persists. "Boot with an empty store" and "Boot with a populated store" have no instance: no store, no reconciliation. |
| UA-007 | "Rebuild is drilled and timed" | partly: rebuild drill only | *Executed:* the rebuild drill below. It covers a fresh set from the pinned sources, a clean build in 68.2 s (first attempt, no fetch failure), and 68.7 s from `mkapp.sh` to the image. One boot on a fresh QEMU process (TCG, 0.3 s; KVM, 1.1 s) prints `hi`, QEMU 33, and `check-image.sh` passes. Every boot is a new virtual machine (one QEMU process per boot, no disk). | "destroy the running appliance, boot the pinned image on a fresh virtual machine, attach the store, and record elapsed time and reconciliation results": there is no running appliance, no store and no invocation. No reconciliation was recorded, and "every outstanding invocation reconciled once, and service resumed" has no instance. "the drill SHALL be repeated for every image change before promotion": the drill was run once, for one image (hello), and nothing is promoted. |
| UA-008 | "Clock and entropy are checked at boot" | not met | *Review-only:* `host.c` checks the monotonic clock only inside `Unikraft.sleep`, and only in images built with `WRIT_HOST_LAYER=y` (the drill image links no `writ_uk` symbol). Those failure paths "have never been exercised" (docs/UNIKERNELS.md, "Port status", Console and time effects; INVENTORY.md, `host.c` bounds). `CONFIG_LIBUKRANDOM` is not set, and no virtual random device is configured (drill configuration). | "The appliance SHALL verify a monotonic clock at boot and deny protected work when it is unavailable": no boot-time clock check exists, and no protected request path denies on clock failure. "SHALL deny challenge issuance when no trusted entropy source is present": no entropy source and no challenge issuance exist, so neither scenario has an instance. |
| UA-009 | "The trusted base is stated" | met (document); scenario precondition partly met (the spec's "a passing drill and corpus under KVM": the corpus passed under KVM, but the drill run here is not UA-007's) | The "Trusted-base statement" section below names the hypervisor (QEMU 11.1.2, TCG and KVM), the host kernel (7.2.9-1-MANJARO, with KVM), the firmware (SeaBIOS 1.17.0-2-2, plus the iPXE option ROM of QEMU's default card), and the unikernel (Unikraft 0.21.0 and every library linked). It scopes the Linux-kernel claim to the guest. The corpus under KVM passes (verification/unikernel-kvm.txt, "Result (KVM), strict checks before the fragment rule", "Fix round 2"), and the drill image boots under KVM (drill below). | "a passing drill and corpus under KVM on a given host": the corpus passes under KVM, but the drill here is the rebuild drill, not UA-007's reconciliation drill (UA-007 row). |
| UA-010 | "Evidence is separated by execution environment" | met for the environments that exist | *Executed:* QEMU TCG results are in their own files (unikernel-corpus-qemu.txt, unikernel-fault-qemu.txt, unikernel-exit-codes.txt, unikernel-effects-qemu.txt, unikernel-channel-qemu.txt, each labelled an emulated boot). KVM results are only in verification/unikernel-kvm.txt, whose same-session TCG controls are labelled TCG ("Same-session TCG controls"). `linuxu` process execution is in verification/unikernel-linuxu.txt. In this file, the drill's TCG and KVM boots are kept apart and named. GPU: `GpuExample.bend` prints its CPU-fallback line, "Native GPU dispatch requested; CPU fallback is allowed. No device attestation.", recorded as "not GPU evidence" (unikernel-corpus-qemu.txt, header). The corpus ran `--gpu off` on one lane. | No physical deployment exists, so there are no "physical deployment results". The library image is emulated-boot and hardware-accelerated-virtualization evidence only. `GpuExample.bend` was not booted under KVM. |

Summary: none of UA-001 to UA-010 is fully met for the library image as an appliance.
UA-003 (with the 782 count), UA-009 and UA-010 are met for what exists. UA-001 and UA-007
are partly met. UA-002, UA-004, UA-005, UA-006 and UA-008 are gaps. Each gap is quoted above,
and each one is an appliance-host deliverable (`openspec/changes/add-unikernel-appliance-host/tasks.md`),
which this lane does not implement.

## Rebuild drill (executed 2026-11-05 UTC)

The appliance design's drill destroys a running appliance, boots the pinned image on a fresh
VM, attaches the store, and records reconciliation. The library image has no store and no
invocation (UA-006, UA-007), so the drill run here is the part that applies: a clean
rebuild of one image from the pinned sources, timed, and compared with the recorded image.

Image: hello (`scripts/unikernel/Hello.bend`, `c70559d4...`), not the corpus. Recorded image:
`$W/sigeffects/images/hello-qemu` (verification/unikernel-effects-qemu.txt, "Builds (set
sigeffects, ...)": image `d0421dfbf5deb0d535297fadcdc3ffe9878dd05d20524d4b84b8a7024ca0079c`,
`.dbg` `d57807824c8c5fb0b6223a977aa6eec6788dd6f8ec3351c362da44364ad10288`, built
2026-11-04T21:54Z with the same Kraftfile, build.sh, Makefile.uk `a2b00918...` and
exit_device.c `c4012e46...`, the hashes in the tree now).

Inputs rechecked before the build:

    git -C $W/src/unikraft rev-parse HEAD    -> 7351f8b563c9e6773da9fdd5bacde6ac91e32112 (status clean)
    git -C $W/src/libs/musl rev-parse HEAD   -> 5fed64ecd7f8abb29df444c73df6d797d4efa18f (status clean)
    sha256 $W/tools/kraftkit-0.12.16/kraft   -> cd7ffa22655c788bda2abc3aacd01e2ec9246ed88fe6cde19e059d66f15106c7
    kraft 0.12.16 (b5dd63da...), gcc 16.2.1 20260810, GNU ld 2.47, GNU Make 4.4.1, QEMU 11.1.2
    sha256 hosts/unikraft/app/Kraftfile      -> ea31944043807789720f42c2267bb16082b4b177e6164a6dc2eba6299390a4ce
    sha256 hosts/unikraft/scripts/build.sh   -> 67ceb9d2b074ec39b7d0c3f9918022974e3fe38af7954b17c1b3bbe1a4fc2817
    (all equal to verification/unikernel-pins.txt)

Commands (from the worktree root; `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH" BEND_NO_TELEMETRY=1`; W from env.sh):

    hosts/unikraft/scripts/mkapp.sh drillhello                              # new set; 0.03 s
    bend scripts/unikernel/Hello.bend -o $W/drillhello/gen/hello.c           # 0.45 s
    hosts/unikraft/scripts/build.sh drillhello hello                         # clean build; 68.2 s
    hosts/unikraft/scripts/check-image.sh drillhello drill-hello hello $W/sigeffects/hello-ref.txt 33 "" 60 1024
    hosts/unikraft/scripts/run.sh drillhello drill-kvm-hello hello "+RTS --threads 1 --gpu off" 60 1024 "" kvm
    WRIT_NO_BOOT=1 hosts/unikraft/scripts/check-image.sh drillhello drill-kvm-hello hello $W/sigeffects/hello-ref.txt 33 "" 60 1024

The two boots ran at about 01:32Z and 01:33Z, under the check scripts of Task 1's first fix
round (972d5fe). Task 1's fix round 2 (e944b22, committed 01:34:34Z) then tightened the
fragment rule in `env.sh`, `check-image.sh` and `check-fault.sh`. Both captures were checked
again with `WRIT_NO_BOOT=1 check-image.sh` under e944b22. Both PASS (diff empty, QEMU 33,
`dropped 0`), so no fragment was dropped under either rule.

Elapsed wall time (host load average 27 to 47 during the drill; indicative only):

| Step | Start (UTC) | Elapsed |
| --- | --- | --- |
| `mkapp.sh drillhello` | 01:30:10 | 0.03 s |
| emit `hello.c` (Bend 2.0.39) | 01:30:11 | 0.45 s |
| clean build, attempt 1 (rc 0; musl fetched, no failure, no retry) | 01:30:11 | 68.2 s |
| new set to image | 01:30:10 to 01:31:19 | **68.7 s** |
| one boot, TCG, `check-image.sh` (PASS) | about 01:32:00 | 0.3 s QEMU wall, 0.48 s for the check |
| one boot, KVM, `run.sh` + `check-image.sh` (PASS) | about 01:33:15 | 1.1 s QEMU wall |

Outputs:

    260b70a3671e52b8fe8f81ae064f40b415b654faf6c27fe0a495a476945d56cf  $W/drillhello/gen/hello.c  (3074 lines; = pins, = sigeffects)
    7d5b0b6062521e4627e099e4c9dc8248d32a30285e959b7eecaa780cf8cfd4a4  musl-1.2.3.tar.gz fetched by this build (= pins)
    caaf77660d5326258984d9c14b76cb3cfb79f60299a140b64fcb707ee1679d6b  $W/drillhello-unikraft/.config.writ-bend_qemu-x86_64
      diff against $W/sigeffects-unikraft/.config...: only line 10, CONFIG_UK_APP (the app directory path)
    "-include uk/config.h" on the compile line of libposix_process/shutdown.o (shutdown.o.cmd: 1 match)
    Kraftfile, Makefile.uk, Config.uk in $W/drillhello-unikraft: cmp-equal to hosts/unikraft/app/
    f8f49e7d9f714e24f1784bea5a85f14c26cc9f2dc824738e6566641195c3c2cd  $W/drillhello/images/hello-qemu
    1eff1720c79b5fd9acb5e259d725542fa95dcbeb6cd525ffee8a19c24c801b15  $W/drillhello/images/hello-qemu.dbg

### Comparison

Hash against the record: **different**, as expected. Image `f8f49e7d...` against the
recorded `d0421dfb...`, and `.dbg` `1eff1720...` against `d5780782...`. Unikraft clean
builds embed the build time, so two clean builds of the same inputs never share a hash
(verification/unikernel-pins.txt, last paragraph of "Unikraft image configuration pins";
INVENTORY.md, "Image hashes are per build"). This is the UA-002 gap.

Since the hash cannot match, four other things were compared, each recorded image against
the drill image:

| Compared | Command | Result |
| --- | --- | --- |
| Which bytes differ (booted image) | `cmp -l` | 6 bytes, at offsets 1116878 to 1116887. All of them fall inside the 25-byte string at offset 1116868 in section `.uk_libinfo` (file offset 0x110410, size 0xb64): `2026-11-04T21:55:19+00:00` in the record, `2026-11-05T01:30:55+00:00` in the drill. `strings -n 6` differs in that one line only. |
| Image with the build time masked | both copies with those 25 bytes overwritten by `X`, then `cmp` and sha256 | **byte-identical**, both `85b8fa4051d96d252d8c324c72576fdf8b500e8bb77bb0f164963b229a77ce3c` |
| Sizes | `stat -c %s`; `size -A` (24 lines) | image 1193040 = 1193040; `.dbg` 12364736 = 12364736; `size -A` identical (`.text` 825429, `.rodata` 283264, `.data` 12224, `.bss` 352256, total 1527244). `.text`, `.rodata`, `.data` extracted with `objcopy -O binary -j` are byte-identical. |
| Symbol inventory | `nm <image>.dbg \| sort` (address, type, name) | identical, 4523 symbols; `nm ... \| grep -c writ_uk` 0 |
| The binary check's result | `sh scripts/runtime-profile/check-binary.sh <image>.dbg` | both: `effect rows: IO.print`, `result: PASS ...`, exit 0; output identical after the `binary:` line |
| Link set | object names in `.unikraft/build/writ-bend_qemu-x86_64.dbg.cmd` | identical, 55 objects (listed below) |
| Program lines on one boot (TCG) | `check-image.sh` against `$W/sigeffects/hello-ref.txt` (`98ea6e4f...`, the line `hi`); `console.sh` on both captures, then `diff` | PASS: diff empty, QEMU 33, `kernel shutdown fragment after exit: dropped 0`. The drill boot's program lines equal the recorded boot's (`$W/sigeffects/logs/run-s2-hello.raw`): `hi`. Log `$W/drillhello/logs/run-drill-hello.log` (`bdd56ea6...`). |
| Program lines on one boot (KVM, recorded apart) | `run.sh ... "" kvm`, then `WRIT_NO_BOOT=1 check-image.sh` | PASS: `hi`, QEMU 33, dropped 0, wall 1.1 s. Log `$W/drillhello/logs/run-drill-kvm-hello.log`. |

The `.dbg` files differ in 752218 bytes. They hold debug info with the build paths: the app
directory (`sigeffects-unikraft` against `drillhello-unikraft`) and the source worktree
that `WRIT_HOSTS_UNIKRAFT` pointed to. The `.dbg` is not booted. Its symbol table is
identical (above).

Conclusion: the rebuild reproduces the recorded booted image exactly, except for the
embedded build time, and it boots to the same program lines. It does **not** reproduce the
image hash, so UA-002 stays a gap. This is the rebuild half of UA-007 only; the
reconciliation half has no store to run against.

## Trusted-base statement

This statement covers every image made from `hosts/unikraft/app/` with `build.sh` (the
evidence files' sets `sig*`, `drillhello`, and the KVM boots in unikernel-kvm.txt). It is a
statement of what the evidence runs on and trusts. It is not a qualification of an appliance.

**The trusted base includes the host.** These images run on a hypervisor, on a host kernel,
behind firmware. All three stay in the trusted base, and so does the unikernel itself. The
guest contains no Linux kernel, so a Linux kernel vulnerability does not run *inside the
guest*. That claim is scoped to the guest only. The image narrows the code inside the
guest's single address space. It does not remove the host from the trust boundary, and it
gives no immunity to host compromise.

Trusted components outside the image (UA-009's four, with the unikernel below):

- Hypervisor: QEMU 11.1.2 (`qemu-system-x86_64`; Arch packages qemu-base and
  qemu-system-x86 11.1.2-1). Used two ways: TCG software emulation (`-accel tcg -cpu max`),
  and hardware-accelerated KVM (`-accel kvm -cpu host`, AMD Ryzen 9 5950X; verification/unikernel-kvm.txt, "Machine").
  QEMU also provides the virtual devices the image uses: the two ISA serial ports (COM1
  console, COM2 channel), `isa-debug-exit` at 0xf4, and the default card the image does not drive.
- Host kernel: Linux 7.2.9-1-MANJARO, with its KVM module for the KVM boots.
- Firmware: SeaBIOS (version Arch Linux 1.17.0-2-2), QEMU's `bios-256k.bin`
  (`b7dea28b1ab93d43f427232f5f6ab07c828fd97765d9b1daaf1b1712b39946e2`, package seabios
  1.17.0-2), which loads the image through `-kernel`; and the iPXE option ROM of QEMU's
  default card (shown on the console before `Booting from ROM`). The firmware runs before the
  image and is not covered by any check here.

The unikernel and everything linked into the image (trusted; all in the guest's one address
space, all with full privilege). Unikraft 0.21.0 (RELEASE-0.21.0, `7351f8b5`) and lib-musl
RELEASE-0.21.0 (`5fed64ec`) with musl 1.2.3 (tarball `7d5b0b60...`), as pinned in
verification/unikernel-pins.txt. The link set is the 55 objects of the drill build
(`$W/drillhello-unikraft/.unikraft/build/writ-bend_qemu-x86_64.dbg.cmd`), identical to the
recorded hello build's:

- Platform and boot: `libkvmplat` (plat/kvm, qemu/x86_64), `libukplat_native`, `libukboot`,
  `libukboot_main`, `libuklcpu`, `libukpcpuvar`, `libukintctlr`, `libukintctlr_xpic`,
  `libukpm`, `libukpal`, `libcontext`, `libisrlib`.
- Memory: `libukalloc`, `libukallocbbuddy`, `libukallocstack` (stack page guards),
  `libukfalloc`, `libukfallocbuddy`, `libukvmem`, `libukpaging`, `libposix_mmap`.
- Scheduling and locking: `libuksched`, `libukschedcoop` (cooperative), `libuklock` (mutex,
  rwlock, and the semaphore the signal library selects), `libukatomic`, `libposix_futex`.
- POSIX process with signals: `libposix_process`, built with **the experimental signal
  library**: `CONFIG_LIBPOSIX_PROCESS_SIGNAL=y`, marked EXPERIMENTAL at
  `lib/posix-process/Config.uk:78-79`. It selects `LIBPOSIX_PROCESS_MULTITHREADING`,
  `LIBPOSIX_PROCESS_EXECVE`, `LIBUKLOCK` and `LIBUKLOCK_SEMAPHORE`, and with them
  `libukbinfmt` (no loader registered: UA-001 row). Also `libposix_environ`,
  `libposix_sysinfo`, `libposix_time`, `libsyscall_shim`.
- Descriptors and files: `libposix_fd`, `libposix_fdio`, `libposix_fdtab`, `libposix_pipe`,
  `libposix_poll`, `libposix_tty` (serial stdio, stdin null), `libposix_vfs`,
  `libposix_vfsroot`, `libukfile`, `libukfile_pseudo`, `libukfs`.
- Console and devices: `libukconsole`, `libns16550` (COM1, and COM2 for the channel),
  `libvgacons`, `libukprint`, `libukdebug` (crash screen, assertions on), `libukstreambuf`.
- Support: `libukargparse`, `libukbitops`, `libuktimeconv`, `libuklibid` (the embedded build
  time).
- C library: `libmusl` and `libmuslglue` (lib-musl over musl 1.2.3).
- Application: `appwritbend` = the Bend program's generated C (`app.o`), Writ's
  `hosts/unikraft/exit_device.c` (the termination and crash hook, in every image unless
  `WRIT_EXIT_HOOK=n`), and Unikraft's `libinfo.libuklibid.o`. Images built with
  `WRIT_HOST_LAYER=y` (the effects probe, the channel monitor) also link `host.c` and the
  effect twins' C (`hosts/unikraft/INVENTORY.md`). The drill image does not
  (no `writ_uk` symbol).

Build configuration pins that change what is linked (verification/unikernel-pins.txt, "Unikraft
image configuration pins"):

- `hosts/unikraft/app/Kraftfile` (`ea319440...`), including `CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'`,
  `CONFIG_UKPLAT_CPU_MAXCOUNT: 1`, `CONFIG_LIBUKBOOT_MAINTHREAD`, `CONFIG_LIBNS16550_COM2`.
- The build flag in `hosts/unikraft/scripts/build.sh` (`67ceb9d2...`):
  `UK_CFLAGS="-std=gnu11 -include uk/config.h"`, applied to every compilation unit. It works
  around 0.21.0's include order in `lib/posix-process/shutdown.c` (`signal.h:116`/`:287`).
  No Unikraft source is patched.

Origin of the generated C: `app.c` is the output of the pinned Bend 2.0.39 toolchain
(`$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend`, `BEND_NO_TELEMETRY=1`),
emitted from an in-tree Bend program (`bend <program>.bend -o $W/<set>/gen/<probe>.c`) and
never edited (`build.sh` copies it). It carries the Bend runtime that the compiler emits. The
Bend compiler and its runtime are therefore part of the trusted base. Build-time trust also
covers kraft 0.12.16, gcc 16.2.1, GNU binutils 2.47 and GNU Make 4.4.1 on this host
(verification/unikernel-pins.txt). No build container is pinned (UA-002 row).

Outside the image (not linked into the guest):

- QEMU, the host kernel and the firmware run outside the image. They remain **trusted**,
  as listed above. "Outside the image" does not mean "outside the trust boundary".
- The harness scripts `hosts/unikraft/scripts/run.sh`, `console.sh`, `check-image.sh`,
  `check-corpus.sh`, `check-fault.sh`, `check-channel.sh`, `env.sh`, the host-side client
  `hosts/unikraft/probes/client/client.c`, and `scripts/runtime-profile/check-binary.sh`. These
  are evidence tooling on the host. They are not in the guest and decide nothing for it. They
  are trusted only for the PASS and FAIL verdicts they print, which is why each one exits
  nonzero when an expected outcome changes (`hosts/unikraft/INVENTORY.md`).
- `mkapp.sh` and `build.sh` are build tooling. Their only effect on the image is through
  the configuration pins above.
