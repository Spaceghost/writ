### Task 1: The Bend package and the dev shell

Write `flake.nix` with:

- `packages.x86_64-linux.bend`: the pinned release as described, with a `passthru.tests.version` or a `checks` entry that runs `bend version` and asserts the output contains `2.0.39`.
- `packages.x86_64-linux.openspec`: OpenSpec 1.16.0 as described.
- `devShells.x86_64-linux.default`: `bend`, `openspec`, `clang` (the newest clang in the pinned nixpkgs; record its version), `qemu`, `nodejs` (22 or newer), `bun`, `python3`, `git`, `gh`, and `gnumake`, with `BEND_NO_TELEMETRY=1` exported in `shellHook` and a one-line banner printing the Bend and OpenSpec versions.
- `formatter` set to `nixpkgs-fmt` or `alejandra` (pick one, record it).

Run `nix flake check` (expect the version check to pass), `nix develop --command bend version`, and `nix develop --command openspec --version`. Record the three commands and their outputs in `verification/nix-shell.txt`.

Add a section "Nix" to `docs/INSTALL.md` after the manual install section: how to enter the shell, that the manual instructions remain valid and describe the same pinned versions, and the flakes-enablement note if needed.

Acceptance: `nix flake check` passes; the two `nix develop --command` outputs show `2.0.39` and `1.16.0`; the evidence file and the INSTALL section exist; `flake.lock` committed.

