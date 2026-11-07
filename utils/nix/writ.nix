# Writ library builds and checks for the flake.
#
# These derivations only run the pinned Bend compiler over the authored Bend
# sources; nothing here implements policy. Every build runs in the Nix sandbox
# with no network access: the only inputs are the filtered source tree, the
# pinned Bend release, clang, and (for the specification check) OpenSpec.
#
# The test assertions pin the current integrated suite (VERIFICATION.md): the
# library driver prints both "PASS:" and "PASS " lines; together they number
# 2271, and the final line is "ALL LIBRARY TESTS PASSED".
{ pkgs, bend, openspec, clang }:

let
  inherit (pkgs) lib;
  fs = lib.fileset;
  root = ../../.;

  # Authored .bend files, including the root, examples/ and hosts/ tests. contrib/ has its
  # own Bend tree and is not imported by the library; docs, specifications,
  # recorded evidence, scripts, planning notes, and the flake itself are not
  # compiler inputs. Base ships with the compiler, so no other file is needed.
  bendSource = fs.toSource {
    inherit root;
    fileset = fs.difference
      (fs.fileFilter (file: file.hasExt "bend") root)
      (fs.unions (map fs.maybeMissing [
        ../../contrib
        ../../docs
        ../../openspec
        ../../verification
        ../../scripts
        ../../.superpowers
        ../../nix
      ]));
  };

  # The OpenSpec tree alone; `openspec validate` reads ./openspec from the
  # working directory.
  specSource = fs.toSource {
    inherit root;
    fileset = ../../openspec;
  };

  # The compiler may write a cache under $HOME; the sandbox HOME is not
  # writable, so each build points it at its own temporary directory.
  # BEND_NO_TELEMETRY is also set by the wrapper; it is repeated so that the
  # intent is visible here.
  bendEnv = ''
    export HOME=$(mktemp -d)
    export BEND_NO_TELEMETRY=1
    export CC=${clang}/bin/clang
  '';

  # Fails unless the captured test output ends with the success line and has
  # exactly 2271 lines beginning with PASS ("PASS:" and "PASS " forms together).
  assertTests = log: ''
    last=$(tail -n 1 ${log})
    passes=$(grep -c '^PASS' ${log} || true)
    echo "final line: $last"
    echo "PASS lines: $passes"
    if [ "$last" != "ALL LIBRARY TESTS PASSED" ]; then
      echo "expected final line ALL LIBRARY TESTS PASSED" >&2; exit 1
    fi
    if [ "$passes" != 2271 ]; then
      echo "expected 2271 PASS lines, found $passes" >&2; exit 1
    fi
  '';

  # Compiles named Bend entry points to native binaries under $out/bin.
  nativeBuild = name: entries: pkgs.stdenvNoCC.mkDerivation {
    inherit name;
    src = bendSource;
    nativeBuildInputs = [ bend clang ];
    dontConfigure = true;
    dontFixup = true;
    buildPhase = ''
      runHook preBuild
      ${bendEnv}
      mkdir -p $out/bin
      ${lib.concatMapStringsSep "\n" (e: ''
        echo "bend ${e.src} -o $out/bin/${e.bin}"
        bend ${e.src} -o $out/bin/${e.bin}
      '') entries}
      runHook postBuild
    '';
    dontInstall = true;
  };

  tests-native = nativeBuild "writ-tests-native" [
    { src = "Tests.bend"; bin = "tests-native"; }
  ];

  examples-native = nativeBuild "writ-examples-native" [
    { src = "Example.bend"; bin = "example"; }
    { src = "examples/Flow.bend"; bin = "flow"; }
    { src = "examples/Transfer.bend"; bin = "transfer"; }
    # CPU build of GpuExample.bend with no device program; not GPU evidence.
    { src = "GpuExample.bend"; bin = "gpu-example"; }
  ];

  check = name: inputs: script: pkgs.runCommand name { nativeBuildInputs = inputs; } script;
in
{
  inherit tests-native examples-native;

  checks = {
    # The library suite on Bend's bundled JavaScript runner.
    tests-js = check "writ-tests-js" [ bend ] ''
      ${bendEnv}
      cd ${bendSource}
      bend Tests.bend 2>&1 | tee $TMPDIR/tests.log
      test "''${PIPESTATUS[0]}" = 0 || { echo "bend Tests.bend exited nonzero" >&2; exit 1; }
      ${assertTests "$TMPDIR/tests.log"}
      cp $TMPDIR/tests.log $out
    '';

    # The native binary from packages.tests-native, as a CPU run. --gpu off
    # runs device-requesting calls on the CPU; this is not a GPU test.
    tests-native = check "writ-tests-native-run" [ ] ''
      ${tests-native}/bin/tests-native +RTS --threads 4 --gpu off 2>&1 | tee $TMPDIR/tests.log
      test "''${PIPESTATUS[0]}" = 0 || { echo "tests-native exited nonzero" >&2; exit 1; }
      ${assertTests "$TMPDIR/tests.log"}
      cp $TMPDIR/tests.log $out
    '';

    # The selected laws in PROOF.bend under Bend's checker. This does not run
    # the independent kernel (--verdict), which needs the Lean toolchain.
    proofs = check "writ-proofs" [ bend ] ''
      ${bendEnv}
      cd ${bendSource}
      bend PROOF.bend 2>&1 | tee $TMPDIR/proofs.log
      test "''${PIPESTATUS[0]}" = 0 || { echo "bend PROOF.bend exited nonzero" >&2; exit 1; }
      grep -qx 'ALL PROOFS CHECK' $TMPDIR/proofs.log || { echo "expected ALL PROOFS CHECK" >&2; exit 1; }
      cp $TMPDIR/proofs.log $out
    '';

    # Structural validation of every OpenSpec spec and change, strict mode.
    # This is separate from the Bend tests and proof checks.
    openspec = check "writ-openspec" [ openspec ] ''
      export HOME=$(mktemp -d)
      export OPENSPEC_TELEMETRY=0
      cd ${specSource}
      openspec validate --all --strict --no-interactive 2>&1 | tee $TMPDIR/openspec.log
      test "''${PIPESTATUS[0]}" = 0 || { echo "openspec validate exited nonzero" >&2; exit 1; }
      # OpenSpec marks each failing item with a cross and ends with a totals line.
      if grep -q '✗' $TMPDIR/openspec.log; then
        echo "openspec reported a failing item" >&2; exit 1
      fi
      grep -Eq '^Totals: [0-9]+ passed, 0 failed' $TMPDIR/openspec.log \
        || { echo "expected an OpenSpec totals line with 0 failed" >&2; exit 1; }
      cp $TMPDIR/openspec.log $out
    '';
  };
}
