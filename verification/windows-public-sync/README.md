# Windows public sync delivery evidence

Observed on 2026-11-11 from `Spaceghost/writ` master `be6053d`, with the changes
on local branch `windows/files-on-demand`. [inputs.sha256](inputs.sha256) pins
the tested Bend and native/script implementation inputs. The repository-wide
[source manifest](../source-sha256.txt) identifies the delivery tree, including
documentation and logs. Generated modules, executables and downloaded toolchains
remain outside the checkout.

The available host was Linux x86-64, kernel `7.1.10-200.fc44.x86_64`. No native
Windows session was available. **This record does not claim a Windows runtime
pass or a completed Notepad milestone.** The user-requested fallback is delivered:
source implementation, a cross-linked Windows executable, runnable native
smoke, and exact remaining acceptance checks.

## Observed results

| Check | Observed result | Evidence |
| --- | --- | --- |
| New public sync Bend corpus, bundled JavaScript backend | 30 PASS; ALL PUBLIC SYNC TESTS PASSED | [model-tests.log](model-tests.log) |
| Same corpus, native Linux CPU, two threads, GPU disabled | 30 PASS; identical assertion output | [native-tests.log](native-tests.log) |
| Existing library suite | 3,072 PASS; ALL LIBRARY TESTS PASSED | [core-tests.log](core-tests.log) |
| Existing native mount model | 70 PASS including exported case-count check; ALL NATIVE MOUNT MODEL TESTS PASSED | [mount-tests.log](mount-tests.log) |
| Existing ordinary proof check | ALL PROOFS CHECK | [proof.log](proof.log) |
| Generated PublicSync module through the existing Node pipe bridge | Canonical INIT/LIST/READ replies for pinned abc fixture | [bridge.log](bridge.log) |
| Windows x64 C/C++ cross-build and link | Three translation units compiled; PE32+ x86-64 executable linked | [cross-build.txt](cross-build.txt) |
| PowerShell 7.4.6 syntax parsing | Demo.ps1 and Smoke.ps1 parsed without errors | [powershell-parse.log](powershell-parse.log) |
| OpenSpec 1.16.0, all/strict/noninteractive | 46 passed, 0 failed | [openspec.log](openspec.log) |

The native CPU build used pinned Bend 2.0.39 and Zig 0.16.0 as `CC`. The bridge
used native Linux Node 26.10.0. The Windows cross-build used Zig's MinGW target
with Microsoft's `cfapi.h` from win32metadata commit
`15fc870a5e96df7c560877ff30136c0fb5a21e9b`. Missing MinGW declarations for
correlation-vector and USN types were supplied only to that external cross-build,
matching the SDK layouts; they are not shipped in or needed by the MSVC target.
The import library was generated from the named CldApi exports. This is compile
and link evidence, not an MSVC build or native API execution.

Bend release archive SHA-256:
`6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab`.
PowerShell parser archive SHA-256 (verified against release `hashes.sha256`):
`6f6015203c47806c5cc444c19d8ed019695e610fbd948154264bf9ca8e157561`.
No Lean `--verdict` toolchain or GPU verification was run.

## Reproduce the portable checks

From the repository root, with Bend 2.0.39 and an installed native C compiler:

```sh
mkdir -p "$HOME/writ-cloud-build"
bend writfs/PublicSyncTests.bend
bend writfs/PublicSyncTests.bend -o "$HOME/writ-cloud-build/public-sync-tests"
"$HOME/writ-cloud-build/public-sync-tests" +RTS --threads 2 --gpu off
bend Tests.bend
bend writfs/MountTests.bend
bend PROOF.bend
bend writfs/PublicSync.bend -o "$HOME/writ-cloud-build/public-sync.mjs"
openspec validate --all --strict --no-interactive
sha256sum -c verification/windows-public-sync/inputs.sha256
sha256sum -c verification/source-sha256.txt
```

The external cross-build used these equivalent compiler/linker commands, with
the SDK header, compatibility declarations and import library described in
[cross-build.txt](cross-build.txt) available under `$out`:

```sh
zig cc -target x86_64-windows-gnu -DUNICODE -D_UNICODE -c contrib/native-hosts/windows/policy_pipe.c -o "$out/policy_pipe.obj"
zig cc -target x86_64-windows-gnu -DUNICODE -D_UNICODE -c contrib/native-hosts/windows/cloud-files/public_process.c -o "$out/public_process.obj"
zig c++ -target x86_64-windows-gnu -std=c++17 -Wall -Wextra -Wno-unknown-pragmas -DNTDDI_VERSION=0x0A000004 -DUNICODE -D_UNICODE -I "$out/include" -include "$out/include/cross-sdk-compat.hpp" -c contrib/native-hosts/windows/cloud-files/provider.cpp -o "$out/provider.obj"
zig c++ -target x86_64-windows-gnu -municode "$out/provider.obj" "$out/policy_pipe.obj" "$out/public_process.obj" "$out/cldapi.lib" -lbcrypt -ladvapi32 -lshell32 -lole32 -o "$out/writ-cloud.exe"
```

## Native Windows checks still awaiting execution

1. Build the delivered target with MSVC and Windows SDK; record Windows, SDK,
   compiler, Node and Cloud Files availability.
2. Register the per-user NTFS root, view `hello.txt` in Explorer, and confirm name,
   logical size, zero payload fetch/allocation during listing and exact hydration.
3. Run `Smoke.ps1`: ordinary write, abrupt provider termination and fresh-root
   readback, temporary-file replacement and conversion, injected writeback failure,
   exact recovery bytes, restart/retry, and two-root stale-base refusal.
4. Run `Smoke.ps1 -InteractiveNotepad`: save the unique marker in actual Notepad,
   observe COMMIT while it remains open, close it, terminate the provider and compare all saved bytes
   through an empty fresh root. Unattended mode explicitly skips this gate.
5. Observe native in-sync state/USN-fenced calls and successful owned-root removal.
   Forced USN-race fault injection and machine/power-loss durability are not
   established by the portable model or the basic process-restart smoke.

Exact [build/start/remove/test commands](../../contrib/native-hosts/windows/cloud-files/README.md)
and the [PowerShell smoke](../../contrib/native-hosts/windows/cloud-files/Smoke.ps1)
are delivered. Windows-specific failures must be retained rather than converted
to passes. The unimplemented protected host, durable journal and namespace gates
remain open.

## Overlap and preserved behavior

All 43 remote branches were enumerated and there were no open PRs at inspection.
The 15 Windows/durable lanes were searched for Cloud Files implementations.
`lane/windows-combined-ad` and related lanes contain initialization/confinement
experiments; `lane/durable-publication` supplies pure journal/encoding models but
no native host transaction. None contains a Cloud Files provider to reuse.
The master object/version and artifact types, SHA-256, bounded frame parser,
native pipe transport and Node invocation harness were reused directly.

WinFsp `writfs.c`, `worker.c`, `isolation.c`, `policy_pipe.c`, the parent CMake
target, `Mount.bend` and `MountAuthority.bend` are unchanged from master. The
separate public executable links its own per-user process-security binding;
it never changes the protected executable's Administrators/SYSTEM binding or
routes protected data into ordinary Notepad. Existing native confinement limits
and failures retain their prior status.
