{
  # Nix tooling for Writ. This flake pins the toolchain that Writ's verification
  # record depends on (Bend 2.0.39, OpenSpec 1.16.0); it is not part of Writ's
  # implementation, which remains Bend 2. See docs/INSTALL.md, section "Nix".
  description = "Pinned Bend 2.0.39 and OpenSpec 1.16.0 toolchain for Writ";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # The pinned Bend release is published for Linux x86_64; other systems are
      # not claimed here (docs/INSTALL.md).
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      bend = pkgs.callPackage ./nix/bend.nix { };
      openspec = pkgs.callPackage ./nix/openspec { };

      # Newest released clang in the pinned nixpkgs (23.1.3 at the locked
      # revision), exported as CC for native Bend builds.
      clang = pkgs.llvmPackages_latest.clang;

      writ = import ./nix/writ.nix { inherit pkgs bend openspec clang; };
    in
    {
      packages.${system} = {
        inherit bend openspec;
        inherit (writ) tests-native examples-native;
        default = bend;
      };

      checks.${system} = {
        # Fails unless the store copy of Bend runs and reports the pinned version.
        bend-version = pkgs.runCommand "bend-version-check" { nativeBuildInputs = [ bend ]; } ''
          export HOME=$TMPDIR
          out_text=$(bend version)
          echo "$out_text"
          case "$out_text" in
            *2.0.39*) ;;
            *) echo "expected Bend 2.0.39" >&2; exit 1 ;;
          esac
          touch $out
        '';
        # Fails unless the packaged OpenSpec reports exactly 1.16.0.
        openspec-version = pkgs.runCommand "openspec-version-check" { nativeBuildInputs = [ openspec ]; } ''
          export HOME=$TMPDIR
          v=$(openspec --version)
          echo "$v"
          test "$v" = "1.16.0" || { echo "expected OpenSpec 1.16.0" >&2; exit 1; }
          touch $out
        '';
      } // writ.checks;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          bend
          openspec
          clang
          pkgs.qemu
          pkgs.nodejs_22
          pkgs.bun
          pkgs.python3
          pkgs.git
          pkgs.gh
          pkgs.gnumake
        ];
        shellHook = ''
          export BEND_NO_TELEMETRY=1
          # OpenSpec also has outbound telemetry and a version check; keep both off.
          export OPENSPEC_TELEMETRY=0
          export CC=${clang}/bin/clang
          echo "writ toolchain: $(bend version), openspec $(openspec --version), $(${clang}/bin/clang --version | head -n1)" >&2
        '';
      };

      formatter.${system} = pkgs.nixpkgs-fmt;
    };
}
