# Windows release pathway

The [Writ Windows release workflow](../../../../../.github/workflows/writ-windows-release.yml)
builds the public Files On-Demand preview. Download published installers and
portable executables from [GitHub Releases](https://github.com/Spaceghost/writ/releases).
The ZIP includes `writ-cloud.exe`, Node, the Bend-generated policy, existing bridge,
smoke script and dependency notices. Setup installs the same payload for the
current user and creates Start menu shortcuts. Uninstall unregisters the default
root and retains hydrated files, backing state and recovery copies.

## Release a version

1. Update [VERSION](VERSION) to a new `MAJOR.MINOR.PATCH-preview.N`. Update any
   dependency pins deliberately in [toolchains.json](toolchains.json), refresh
   `verification/source-sha256.txt` for the tracked tree and commit it.
2. Push the branch or open a PR. The workflow runs on `master`, `windows/**`
   branches and relevant pull requests; `workflow_dispatch` can rebuild a ref.
3. After Windows passes for the intended commit, create and push a new tag:

   ```sh
   git tag -a windows-v0.1.0-preview.1 <tested-commit> -m 'Writ Windows public preview 0.1.0-preview.1'
   git push origin windows-v0.1.0-preview.1
   ```

4. The tag workflow rebuilds and retests, checks the tag against VERSION, creates
   a draft prerelease, uploads all assets, then makes it public. Existing releases
   are never overwritten. Failed uploads leave a draft for inspection; recover
   that draft explicitly before retrying. Never move a published tag.

Branch/PR Actions artifacts expire; tagged releases publish permanent downloads.
Only the publish job receives `contents: write`. Actions use commit pins;
downloaded tools use versions and SHA-256. Preview binaries are unsigned.

## Reproducibility and test scope

Linux generates the policy twice with Bend 2.0.39 and compares bytes. It checks
the source manifest and runs the public-sync model, library suite and ordinary
proofs. Windows checks generated-artifact checksums and source revision, runs the
model on bundled Node, and builds in two clean directories with MSVC `/Brepro`.

The two native EXEs, portable ZIPs and setup EXEs must match byte-for-byte. ZIP
entry order and timestamps are stable; installer timestamps are omitted.
`BUILD-INFO.json` records source, manifest hash, dependencies, SDK, actual compiler,
CMake, PowerShell and image. SDK and MSVC family are selected explicitly. Hosted
images and MSVC servicing revisions can change; independent cross-image byte
identity is not claimed. Reproduce the recorded environment for that comparison.

The exact portable ZIP is extracted into a path with spaces and exercised by
[Smoke.ps1](../Smoke.ps1). The installer payload is hash-checked and its default
command hydrates a file. Uninstall must stop the running provider, unregister its
root and remove the app while preserving hydrated bytes and backing state.
Failed logs are retained; successful releases include verification logs.

CI uses the hosted runner's account. Interactive Notepad/Explorer, a separate
standard-account desktop, and protected WinFsp qualification remain separate
gates. The install probe never changes Windows service configuration; only the
workflow prepares the existing Cloud Files filter on its disposable runner.

## Rebuild without publishing

On Linux x64 with Git, jq, curl and tar, from a clean tagged checkout:

```sh
bash contrib/native-hosts/windows/cloud-files/release/Generate.sh "$HOME/writ-release-generation"
```

Copy `policy` to Windows. With PowerShell 7.4+, CMake 4.2+, Visual Studio 2026
including its MSVC 14.44 compatibility tools, and Windows SDK 10.0.26100.0,
in the same checkout:

```powershell
./contrib/native-hosts/windows/cloud-files/release/Package.ps1 -PolicyDir C:\path\policy -OutputDir "$env:LOCALAPPDATA\WritReleaseBuild"
./contrib/native-hosts/windows/cloud-files/release/Test-Package.ps1 -OutputDir "$env:LOCALAPPDATA\WritReleaseBuild"
```

Outputs must be new directories outside the checkout. The install probe requires
unused default Writ paths and retains fixture data. Run the packaged `Smoke.ps1`
with `-PackageDir <directory> -InteractiveNotepad` for the actual editor gate.
Ordinary use of the packages needs no compiler, PowerShell or separate Node.

## Packaging source and trust

`Generate.sh` downloads verified Bend and invokes it. `Package.ps1` verifies,
builds and stages the payload and invokes pinned Inno Setup. `Writ.iss` defines
installation and calls native cleanup, aborting uninstall on failure.
`Test-Package.ps1` probes OS installation/launch/removal. Default native commands
resolve package/user paths and reuse Provider and the Bend monitor. No runtime
policy or authorization decision is reimplemented in packaging.

Upstream inputs: [Node checksums](https://nodejs.org/dist/v22.23.4/SHASUMS256.txt),
[Inno Setup 6.7.4](https://github.com/jrsoftware/issrc/releases/tag/is-6_7_4),
[installer timestamps](https://jrsoftware.org/ishelp/topic_filessection.htm),
and [Cloud Files unregistration](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfunregistersyncroot).
