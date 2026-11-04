# OpenSpec 1.16.0, packaged from the published npm tarball with buildNpmPackage.
#
# The registry tarball already contains the compiled dist/, so nothing is built.
# package-lock.json beside this file was generated with
#   npm install --package-lock-only --ignore-scripts
# from the release's package.json with devDependencies removed, so only runtime
# dependencies are fetched. postPatch applies the same removal so `npm ci`
# sees a package.json that matches the lock.
{ lib
, buildNpmPackage
, fetchNpmDeps
, fetchurl
, nodejs_22
, jq
}:

buildNpmPackage (finalAttrs: {
  pname = "openspec";
  version = "1.16.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@fission-ai/openspec/-/openspec-${finalAttrs.version}.tgz";
    hash = "sha256-PRCmhaNQv0bygBRSQRYXuNRiBsd6nYbdyVwN26TXSAs=";
  };

  nodejs = nodejs_22;
  nativeBuildInputs = [ jq ];

  postPatch = ''
    jq 'del(.devDependencies)' package.json > package.json.new
    mv package.json.new package.json
    cp ${./package-lock.json} package-lock.json
  '';

  # The dependency fetch reads only the committed lock, so it does not depend on
  # postPatch (whose jq is unavailable in the fetcher's environment).
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    src = lib.fileset.toSource { root = ./.; fileset = ./package-lock.json; };
    # npmDepsHash for nix/openspec/package-lock.json
    hash = "sha256-0wnUqswvz7ikZjPCB4Ha51fBmIl2N51lJNpWAJcMMeg=";
  };
  dontNpmBuild = true;

  meta = {
    description = "Spec-driven development CLI used to validate Writ's openspec/ tree";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    license = lib.licenses.mit;
    mainProgram = "openspec";
  };
})
