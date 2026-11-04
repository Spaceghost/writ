# Library-unikernel Bend runtime: design

## Context

`bend Tests.bend -o build/tests.c` emits one C file: program plus runtime. On
Linux that file is compiled with clang and linked against glibc or statically.
A library unikernel such as Unikraft takes an application's C sources and links
them with a selected set of kernel libraries into a bootable image. The runtime
surface is known (BEND-RUNTIME.md). What is unknown is which candidate's
libraries satisfy each row and how the effect loop's self-pipe behaves on a
kernel whose `select` is a library, not a syscall.

The gap: no build configuration, no effect twins for any unikernel, no boot.

## Decisions

### Native link, not ELF loading

The generated C is the application. It is compiled by the unikernel's build
with the unikernel's libc. The ELF-loader or binary-compatibility mode is the
appliance change's route and is not used here. The resulting image contains the
runtime, the monitor, and the kernel libraries the configuration selected, and
nothing else.

### Select by a matrix, Unikraft first

The selection task fills one row per runtime inventory item per candidate:
supplied, substituted, or missing, each established by running it. Unikraft is
tried first because its `linuxu` platform allows the whole port to be debugged
as a Linux process before any VM boot, and its musl threads and `posix-mmap`
match the runtime's expectations on paper. OSv is tried second if Unikraft
misses a row the runtime profile cannot waive. HermitOS may be booted for the
record. The decision and the matrix are published; the proposal does not fix
the answer.

### Effects bind to kernel primitives where that removes a layer

The monitor-profile effects are authored in Bend with C twins. On the chosen
kernel the twins call its console, time, and exit primitives directly instead
of going through libc emulation of Linux syscalls. The authenticated channel
ingress uses the kernel's networking or a virtio transport chosen by the host
contract's channel change. The twins are the only kernel-specific code and are
listed in a trust inventory as authored binding code.

### Lanes and memory follow the profile

Start with one lane and the inline IO helper, which removes the pthread rows
entirely. Add lanes behind the kernel's thread library once the single-lane
corpus passes. The heap and stack reservation use the kernel's anonymous
mapping with a guard; if the kernel cannot reserve lazily, the arena is sized
at build time and exhaustion halts with the runtime's message.

### Faults halt

A page fault in the image reaches the kernel's trap handler. The port installs
a handler that prints the runtime's fault message to the console and halts with
a distinct exit code. The runtime's `sigaltstack` path is replaced by the
profile's halting substitute. Resuming is never configured.

### `linuxu` first, then QEMU, then Firecracker or KVM

Three execution environments, recorded separately: the image as a Linux
process, the image under QEMU software emulation, and the image under a
hardware-accelerated hypervisor. Only the last two are boots. The corpus must
match the Linux single-lane record in each.

### Deployment rules are the appliance's

Image immutability, reproducible hash, single ingress, external state, clock
and entropy checks, the rebuild drill, and the trusted-base statement are UA-001
through UA-010. This change does not restate them; the library image must pass
them like any appliance image.

## Failure and denial behavior

A missing library row fails the link or boot and is recorded in the matrix. A
corpus mismatch fails qualification for that environment. A fault halts with a
recorded code. An effect twin that reaches a primitive outside the profile fails
the runtime profile's binary check.

## Evidence before claiming implementation

- Pinned unikernel version, build configuration, toolchain, and image hash.
- The selection matrix with every cell established by execution.
- Corpus and example output from `linuxu`, QEMU, and an accelerated hypervisor,
  separately.
- Trust inventory for the effect twins.
- The appliance rebuild drill run on the library image.
