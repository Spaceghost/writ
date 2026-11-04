# Task 1 report: Bend package and dev shell

Status: DONE_WITH_CONCERNS (minor; all acceptance criteria met)

## Commits (branch lane/nix-flake, not pushed)
- 0e4e635 Add Nix flake pinning Bend 2.0.39 and OpenSpec 1.16.0
- 9a21376 Record Nix dev shell evidence (verification/nix-shell.txt)

## Files
- flake.nix: packages.{bend,openspec,default}, checks.{bend-version,openspec-version},
  devShells.default, formatter = nixpkgs-fmt (1.3.0).
- flake.lock: nixpkgs github:NixOS/nixpkgs/0bb2eedc20e4739f29e8045034f2828ad7054f8f
  (nixos-unstable, lastModified 2026-11-01, locked 2026-11-03).
- nix/bend.nix: fetchurl of the official v2.0.39 linux-x64 tarball,
  hash sha256-bPRi/Y9wsJSklQ67cJqcT/2PHRGJ2c7fH9Y81dBBx6s= (= INSTALL's
  6cf462fd...c7ab). Whole tree copied to $out/bend (bin/, bend2/, guide/ adjacent);
  $out/bin/bend is a makeWrapper wrapper that sets BEND_NO_TELEMETRY=1 and execs
  $out/bend/bin/bend in place. autoPatchelfHook: binary links only glibc
  (libc/libm/libpthread/libdl); 0 unsatisfied deps; only the interpreter changed.
  The binary is a Bun single-file executable (program in a `.bun` ELF section);
  dontStrip = true. Verified after patchelf: `bend version` and `bend guide` work.
- nix/openspec/default.nix + nix/openspec/package-lock.json: buildNpmPackage from
  the registry tarball (sha256-PRCmhaNQv0bygBRSQRYXuNRiBsd6nYbdyVwN26TXSAs=),
  dontNpmBuild (dist/ ships prebuilt). Lock generated with
  `npm install --package-lock-only --ignore-scripts` (Node 22.23.4) from the
  release package.json with devDependencies removed (56 runtime packages);
  postPatch removes devDependencies the same way so `npm ci` matches.
  npmDeps via explicit fetchNpmDeps over the lock only,
  npmDepsHash sha256-0wnUqswvz7ikZjPCB4Ha51fBmIl2N51lJNpWAJcMMeg=.
  No bunx fallback needed: hermetic.
- docs/INSTALL.md: new "Nix" section after the manual install section.
- .gitignore: added /result*.
- verification/nix-shell.txt: the three commands verbatim, plus a rebuild of the
  two checks (the recorded `nix flake check` ran 0 checks because outputs were
  cached; the rebuild shows them executing in the sandbox).

## Dev shell
bend 2.0.39, openspec 1.16.0, clang 23.1.3 (llvmPackages_latest; newest released;
llvmPackages_git 24.0.0-unstable is a snapshot and was not used), nodejs 22.23.4,
bun 1.4.2, python3 3.14.8, qemu 11.1.2, git 2.56.0, gh 2.103.3, gnumake 4.4.1.
shellHook exports BEND_NO_TELEMETRY=1, OPENSPEC_TELEMETRY=0, CC=<clang 23.1.3>,
and prints a one-line banner to stderr.

## Checks
- nix flake check: all checks passed (sandbox = true).
- nix develop --command bend version: bend 2.0.39
- nix develop --command openspec --version: 1.16.0
- Flakes were already enabled in ~/.config/nix/nix.conf; no extra flag needed.
  INSTALL still documents the --extra-experimental-features option for others.
- Not run: bend Tests.bend / PROOF.bend (no .bend or security change in this task;
  Task 2 runs them inside Nix).

## Concerns
1. clang mismatch: the shell's clang is 23.1.3, but the recorded native run used
   clang 19.1.1. INSTALL says a native run from the shell is a separate run, not a
   reproduction. Task 2's determinism/test evidence will be on clang 23 unless the
   plan switches to llvmPackages_19.
2. Additions beyond the brief: OPENSPEC_TELEMETRY=0 and CC exported in the shell,
   and a second check (openspec-version). Easy to drop if unwanted.
3. Bun-compiled binary + patchelf: works now; a future release that changes the
   section layout should be re-verified after patchelf.
4. VERIFICATION.md was not touched (outside allowed files); it does not yet mention
   the Nix evidence file.
