# Pinned Bend 2.0.39: the official Linux x86_64 release, repackaged unchanged.
#
# The release is not built from source. The tarball is a fixed-output fetch whose
# hash is the SHA-256 recorded in docs/INSTALL.md (converted to SRI form). The
# whole extracted tree is installed under $out/bend so that bin/, bend2/, and
# guide/ stay adjacent: the executable locates its standard library and guides
# relative to its own path. $out/bin/bend is a wrapper that execs the real binary
# in place, so that adjacency is preserved.
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bend";
  version = "2.0.39";

  src = fetchurl {
    url = "https://github.com/bendlang/bend/releases/download/v${finalAttrs.version}/bend-${finalAttrs.version}-linux-x64.tar.gz";
    # sha256 6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab (docs/INSTALL.md)
    hash = "sha256-bPRi/Y9wsJSklQ67cJqcT/2PHRGJ2c7fH9Y81dBBx6s=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  # The binary links only glibc (libc, libm, libpthread, libdl); autoPatchelfHook
  # resolves those from stdenv. stdenv.cc.cc.lib covers libstdc++/libgcc_s should
  # a future release need them.
  buildInputs = [ stdenv.cc.cc.lib ];

  # The executable is a Bun single-file build whose program lives in an ELF
  # section; stripping is unnecessary and must not touch it.
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    test -x bend/bin/bend && test -d bend/bend2 && test -d bend/guide
    mkdir -p $out/bin
    cp -r bend $out/bend
    makeWrapper $out/bend/bin/bend $out/bin/bend --set BEND_NO_TELEMETRY 1
    runHook postInstall
  '';

  meta = {
    description = "Bend 2 compiler and runtime, pinned release used to validate Writ";
    homepage = "https://github.com/bendlang/bend";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "bend";
  };
})
