# Task 1 report: trivial component on base-linux

Status: DONE (with minor concerns, below)
Branch: lane/genode-component (not pushed)
Commits:
- 1d5982d Record Genode 26.08 pins and upstream log scenario on base-linux
- 97ca7a9 Run writ_hello component under init on base-linux
Wall clock: about 10 minutes (20:17 to 20:26 -06:00), well inside the three-hour time-box.

## What was done
1. Pin verification: `git ls-remote` on Codeberg genodelabs/genode shows
   `refs/tags/26.08^{}` = d18ee9e917200b059549e21f2dd9a55bfe61a0eb, which matches
   docs/GENODE.md. Shallow-cloned tag 26.08 into ../writ-genode/genode/.
   `rev-parse HEAD` returned that same hash. Upstream tree left unmodified.
2. Tool chain: doc/tool_chain.txt at the pin prescribes the 25.05 tool chain
   (tool/tool_chain: GCC 14.2.0, binutils 2.44). Downloaded the prebuilt Ubuntu
   24.04 archive; its SHA256 6cab8e5f...eb739 matches the value in the doc. Listed
   the member paths before extracting, extracted to ../writ-genode/toolchain/25.05/
   (no root), and selected it with CROSS_DEV_PREFIX in the build directory's
   etc/tools.conf.
3. Build directory: `create_builddir x86_64`, then BOARD=linux and KERNEL=linux in
   etc/build.conf.
4. Host gap: the host has no /usr/bin/expect, which tool/run/run's shebang names.
   I got expect 5.45.4 from nixpkgs (`nix build --out-link
   ../writ-genode/host-tools/expect`) and added a static-pattern `run/%` rule to
   etc/build.conf for the scenarios `log` and `writ_hello`. The rule is identical
   to upstream's except that it calls the run tool through that expect.
5. Upstream scenario: `make run/log` (repos/base/run/log.run) built core-linux,
   init, ld.lib.so, and test-log in 50 s. It exited 0 with "Run script execution
   successful."; compare_output_to passed. No depot or ports steps were needed.
6. writ_hello: repository ../writ-genode/writ-repo/ with
   src/app/writ_hello/{target.mk,main.cc} and run/writ_hello.run. It is a minimal
   Component::construct with one Genode::log call. init routes only the parent's
   LOG, PD, CPU, and ROM services. Log line:
   `[init -> writ_hello] writ_hello: component constructed on Genode`, exit 0.
   The first attempt timed out (exit 254) because the pty sends "\r\n". I fixed the
   wait pattern to end in `.*\n`, as log.run's does. That failure is recorded as
   evidence that the script exits nonzero when the line is missing.
7. Extra check: in a separate manual start, init and writ_hello showed
   NoNewPrivs 1 and Seccomp 2 in /proc/<pid>/status. core-linux showed 0/0.

## Files (in repo)
- verification/genode-pins.txt: Genode commit, tool chain choice, version and
  hash, host gcc 16.2.1, make, tcl, expect (nix store path and nixpkgs rev).
- verification/genode-bringup-base-linux.txt: commands, verbatim logs for both
  scenarios, the failure path, the seccomp observation, and limits.
- scripts/genode/writ_hello/{target.mk,main.cc,writ_hello.run}: byte-identical
  to the live copies in ../writ-genode/writ-repo/. Each has a header comment.
- scripts/genode/writ_hello/build.conf.fragment: the authored build.conf additions.

Outside the repo (not committed): ../writ-genode/{genode,toolchain,downloads,
host-tools,build,writ-repo,run-log.out,run-writ_hello.out,toolchain-list.txt}.

## Concerns
- verification/source-sha256.txt was already stale at the branch base: 54 tracked
  files, such as docs/superpowers/plans/* and docs/BEND-RUNTIME.md, were missing
  before this task. I did not regenerate it, because parallel lanes would
  conflict. It needs a single regeneration at integration, which will also add the
  new genode-* evidence files and scripts/genode/.
- The run harness depends on the out-of-tree expect rule in build.conf. Anyone
  reproducing the run needs the fragment, or a system expect at /usr/bin/expect.
- Everything here is Genode-on-Linux evidence only. The seccomp observation is
  status-flag level; the filter contents were not inspected.
- tasks.md was not touched, because Task 1 maps to no checkbox.
- The prebuilt tool chain targets Ubuntu 24.04; on this Manjaro host (glibc 2.44)
  it ran without issue.
