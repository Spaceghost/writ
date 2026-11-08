# Writ public-canary runner for an interactive, disposable Windows VM.
# Source and generated policy are the already exported efcfba8 package.
# Output is guest-local; copy it out after the run with authenticated guestcontrol.
# A timeout kills only the retained parent process and stops the sequence: any
# child/resource cleanup after forced termination is UNKNOWN, not a pass.
$ErrorActionPreference = 'Stop'

$root = 'C:\writ-stage\public'
$results = 'C:\writ-stage\results'
$build = 'C:\writ-stage\native-build'
$cmake = 'C:\writ-stage\tools\cmake-4.4.5-windows-x86_64\bin\cmake.exe'
$node = Join-Path $root 'portable-node\node.exe'
$module = Join-Path $root 'generated\mount.mjs'
$model = Join-Path $root 'generated\mount-tests.js'
$bridgeCheck = Join-Path $root 'source\contrib\native-hosts\runtime\check-bridge.mjs'
$bridge = Join-Path $root 'source\contrib\native-hosts\runtime\node-policy.mjs'
$nativeSource = Join-Path $root 'source\contrib\native-hosts\windows'
$winfsp = Join-Path ${env:ProgramFiles(x86)} 'WinFsp'
$winfspDll = Join-Path $winfsp 'bin\winfsp-x64.dll'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$winfspInstaller = 'C:\writ-stage\installers\winfsp-2.2.26286.msi'
$vsInstaller = 'C:\writ-stage\installers\vs_community_2026.exe'
$cmakeArchive = 'C:\writ-stage\installers\cmake-4.4.5-windows-x86_64.zip'
$fixture = Join-Path $results 'public-canary.bin'
$stageNames = @('node-version','cmake-version','vswhere','mount-model','js-bridge',
  'configure','build','probe-startup','native-transport','mount','lpac')

# Never reuse a previous build or evidence directory. On preflight failure before
# creation, the interactive console records the error; no fixture is attempted.
if (Test-Path -LiteralPath $results) { throw "Results directory already exists: $results" }
if (Test-Path -LiteralPath $build) { throw "Build directory already exists: $build" }
New-Item -ItemType Directory -Path $results -ErrorAction Stop | Out-Null
foreach ($name in $stageNames) {
  Set-Content -LiteralPath (Join-Path $results ($name + '.status')) -Value 'NOT_RUN' -Encoding ASCII
}
$summary = Join-Path $results 'summary.txt'
Set-Content -LiteralPath $summary -Value 'Writ Windows public-canary; not protected-host qualification.' -Encoding UTF8

function Require-File([string] $path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
}

function Require-Hash([string] $path, [string] $expected) {
  Require-File $path
  $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected.ToLowerInvariant()) { throw "SHA-256 mismatch: $path" }
}

function Verify-Manifest([string] $manifest, [string] $base, [string] $prefix) {
  Require-File $manifest
  $count = 0
  foreach ($line in Get-Content -LiteralPath $manifest) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed manifest: $manifest" }
    $digest = $Matches[1]
    $relative = $Matches[2]
    if ($relative -notlike ($prefix + '*') -or $relative.Contains('\') -or
        $relative.Contains(':') -or $relative -match '(^|/)\.\.(/|$)') {
      throw "Unsafe manifest entry: $relative"
    }
    Require-Hash (Join-Path $base ($relative.Replace('/', '\'))) $digest
    $count++
  }
  if ($count -eq 0) { throw "Empty manifest: $manifest" }
  Add-Content -LiteralPath $summary -Value "Verified $count entries from $manifest" -Encoding UTF8
}

# All argument lines here are fixed, task-owned paths; no worker/user-controlled
# string is interpolated. Generator name is quoted because it contains spaces.
. 'C:\writ-stage\process-wrapper.ps1'

function Require-Line([string] $name, [string] $pattern) {
  if (-not (Select-String -LiteralPath (Join-Path $results ($name + '.stdout')) -Pattern $pattern -Quiet)) {
    throw "$name exited zero without its expected final line"
  }
}

try {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  $sessionId = [Diagnostics.Process]::GetCurrentProcess().SessionId
  $interactive = [Environment]::UserInteractive
  $elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  $os = Get-CimInstance Win32_OperatingSystem
  $winVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
  @("OS: $($os.Caption) $($os.Version) $($os.OSArchitecture)",
    "Build: $($winVersion.CurrentBuild).$($winVersion.UBR)",
    "Session: $sessionId; UserInteractive: $interactive; elevated administrator: $elevated",
    'Source revision: efcfba835e133a3cb112e631b9ff352f1d38c488',
    'Public fixture only; generated policy runs through native Windows Node.') |
      Set-Content -LiteralPath (Join-Path $results 'environment.txt') -Encoding UTF8
  if ($sessionId -eq 0 -or -not $interactive -or -not $elevated) {
    throw 'Run from an interactive elevated administrator desktop, not guestcontrol session 0.'
  }
  foreach ($path in @($cmake,$node,$module,$model,$bridge,$bridgeCheck,$winfspDll,$vswhere)) { Require-File $path }
  if ((Get-Content -LiteralPath (Join-Path $root 'generated\commit.txt') -Raw).Trim() -ne 'efcfba835e133a3cb112e631b9ff352f1d38c488') {
    throw 'Exported source commit does not match the expected revision.'
  }
  Require-Hash (Join-Path $root 'source-SHA256SUMS') '05225adb280344dcff9c3af87d3676ba1e61a1f72a5235a05eee3562a211be94'
  Require-Hash (Join-Path $root 'generated\SHA256SUMS') 'ab68076b2ddbaafe5bdb299c3ac7f976bc1c2780ecc6f59e458f329a424d2daa'
  Verify-Manifest (Join-Path $root 'source-SHA256SUMS') $root 'source/'
  Verify-Manifest (Join-Path $root 'generated\SHA256SUMS') (Join-Path $root 'generated') ''
  Require-Hash $node 'dccc52de28d8df2ee22d2062424f8c563070d95d8ad70c54c4bf01d590dec14f'
  Require-Hash $cmake '84935c0b7cb09c140de0d3b042d4e93e5fac4e6371e75bf28eae3d841f79dfb3'
  Require-Hash $winfspInstaller '293ffb9bcc0b625c85079fe85fa77f8fe98170aba51a02ac9c83d58f6c3b0e2f'
  Require-Hash $vsInstaller '610e78f66efc960b3cee586c1014f18865d6c51c96b9be358a06fe63e32eed97'
  Require-Hash $cmakeArchive '326c826486d46a23cf9d5a1c9ee3a567d427bdd02c4a34071937a2a675cff004'
  $signatures = @((Get-AuthenticodeSignature -LiteralPath $winfspInstaller),
                  (Get-AuthenticodeSignature -LiteralPath $vsInstaller))
  $signatures | Format-List Path,Status,StatusMessage,SignerCertificate |
    Out-File -LiteralPath (Join-Path $results 'installer-signatures.txt') -Encoding UTF8
  foreach ($signature in $signatures) {
    if ($signature.Status -ne 'Valid') { throw "Invalid installer signature: $($signature.Path) $($signature.Status)" }
  }
  $winfspVersion = (Get-Item -LiteralPath $winfspDll).VersionInfo.FileVersion
  if ($winfspVersion -ne '2.2.26286.14d6e02') { throw "Unexpected WinFsp runtime: $winfspVersion" }
  Add-Content -LiteralPath (Join-Path $results 'environment.txt') -Value "WinFsp DLL: $winfspVersion" -Encoding UTF8
  Get-FileHash -Algorithm SHA256 -LiteralPath $node,$module,$model,$cmake,$winfspDll,$winfspInstaller,$vsInstaller,$cmakeArchive |
    Format-List | Out-File -LiteralPath (Join-Path $results 'input-hashes.txt') -Encoding UTF8
  Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\Windows\System32\ntoskrnl.exe',
    'C:\Windows\System32\kernel32.dll','C:\Windows\System32\kernelbase.dll' |
      Format-List | Out-File -LiteralPath (Join-Path $results 'os-binary-hashes.txt') -Encoding UTF8
  $env:PATH = (Join-Path $winfsp 'bin') + ';' + $env:PATH

  if (-not (Run-Stage 'node-version' $node '--version' 60)) { throw 'Node version check failed' }
  if ((Get-Content -LiteralPath (Join-Path $results 'node-version.stdout') -Raw).Trim() -ne 'v22.23.4') { throw 'Unexpected Node version' }
  if (-not (Run-Stage 'cmake-version' $cmake '--version' 60)) { throw 'CMake version check failed' }
  if (-not (Run-Stage 'vswhere' $vswhere '-all -products * -format json' 60)) { throw 'vswhere failed' }
  if (-not (Run-Stage 'mount-model' $node $model 180)) { throw 'Mount model failed' }
  Require-Line 'mount-model' '^ALL NATIVE MOUNT MODEL TESTS PASSED$'
  if (-not (Run-Stage 'js-bridge' $node ($bridgeCheck + ' ' + $module) 180)) { throw 'JavaScript bridge failed' }
  Require-Line 'js-bridge' '^ALL 9 NATIVE TRANSPORT PROBES PASSED$'

  $configureArgs = '-S ' + $nativeSource + ' -B ' + $build + ' -G "Visual Studio 18 2026" -A x64'
  if (-not (Run-Stage 'configure' $cmake $configureArgs 300)) { throw 'Native CMake configuration failed' }
  Copy-Item -LiteralPath (Join-Path $build 'CMakeCache.txt') -Destination (Join-Path $results 'CMakeCache.txt')
  $compilerRecords = @(Get-ChildItem -LiteralPath (Join-Path $build 'CMakeFiles') -Recurse -Filter CMakeCCompiler.cmake)
  if ($compilerRecords.Count -ne 1) { throw 'Cannot identify the exact C compiler used by CMake' }
  $compilerRecords | ForEach-Object { Get-Content -LiteralPath $_.FullName } |
    Out-File -LiteralPath (Join-Path $results 'cmake-c-compiler.txt') -Encoding UTF8
  $compilerLine = @(Get-Content -LiteralPath $compilerRecords[0].FullName |
    Where-Object { $_ -match '^set\(CMAKE_C_COMPILER "([^"]+)"\)' })
  if ($compilerLine.Count -ne 1 -or $compilerLine[0] -notmatch '^set\(CMAKE_C_COMPILER "([^"]+)"\)') {
    throw 'Cannot extract the exact C compiler path from CMake'
  }
  $compiler = $Matches[1].Replace('/', '\')
  Require-File $compiler
  $linker = Join-Path (Split-Path -Parent $compiler) 'link.exe'
  Require-File $linker
  @("Compiler: $compiler", "Compiler file version: $((Get-Item -LiteralPath $compiler).VersionInfo.FileVersion)",
    "Linker: $linker", "Linker file version: $((Get-Item -LiteralPath $linker).VersionInfo.FileVersion)") |
      Set-Content -LiteralPath (Join-Path $results 'msvc-versions.txt') -Encoding UTF8
  Get-FileHash -Algorithm SHA256 -LiteralPath $compiler,$linker | Format-List |
    Out-File -LiteralPath (Join-Path $results 'msvc-hashes.txt') -Encoding UTF8
  if (-not (Run-Stage 'build' $cmake ('--build ' + $build + ' --config Release --parallel 2') 1800)) { throw 'Native build failed' }
  $release = Join-Path $build 'Release'
  $hostExe = Join-Path $release 'writfs-windows.exe'
  $probe = Join-Path $release 'writfs-probe.exe'
  $transport = Join-Path $release 'writfs-transport-probe.exe'
  foreach ($path in @($hostExe,$probe,$transport)) { Require-File $path }
  Get-FileHash -Algorithm SHA256 -LiteralPath $hostExe,$probe,$transport |
    Format-List | Out-File -LiteralPath (Join-Path $results 'native-binary-hashes.txt') -Encoding UTF8
  Get-ChildItem -LiteralPath $build -Filter '*.vcxproj' |
    Select-String -Pattern 'WindowsTargetPlatformVersion' |
    Out-File -LiteralPath (Join-Path $results 'windows-sdk-project.txt') -Encoding UTF8
  if (-not (Run-Stage 'probe-startup' $probe '--exit' 60)) { throw 'Ordinary probe startup failed' }

  # Native pipe probe precedes the mounted fixtures. On any failure, the
  # remaining stages stay NOT_RUN; no potentially dirty fixture is retried.
  if (-not (Run-Stage 'native-transport' $transport ($node + ' ' + $bridge + ' ' + $module) 300)) { throw 'Native C transport failed' }
  Require-Line 'native-transport' '^ALL WINDOWS NATIVE TRANSPORT CHECKS PASSED \(22 assertions\)$'

  $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes("Writ public native canary`n")
  $file = New-Object System.IO.FileStream($fixture,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try { $file.Write($bytes,0,$bytes.Length) } finally { $file.Dispose() }
  if (((Get-Item -LiteralPath $fixture).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Fixture is a reparse point' }
  Get-FileHash -LiteralPath $fixture -Algorithm SHA256 | Format-List |
    Out-File -LiteralPath (Join-Path $results 'fixture-hash.txt') -Encoding UTF8
  $commonArgs = '--public-fixture ' + $fixture + ' ' + $node + ' ' + $bridge + ' ' + $module + ' ' + $probe + ' '
  if (-not (Run-Stage 'mount' $hostExe ($commonArgs + 'mount') 300)) { throw 'Native mount failed; LPAC remains NOT_RUN and cleanup must be reviewed' }
  Require-Line 'mount' '^ALL WINDOWS NATIVE CHECKS PASSED profile=mount-canary$'
  if (-not (Run-Stage 'lpac' $hostExe ($commonArgs + 'lpac') 300)) { throw 'Strict LPAC failed; retain all INCOMPLETE and observation lines' }
  Require-Line 'lpac' '^ALL WINDOWS NATIVE CHECKS PASSED profile=lpac-canary$'
  Add-Content -LiteralPath $summary -Value 'All requested stages exited zero. This is bounded public-canary evidence, not host qualification.' -Encoding UTF8
  exit 0
} catch {
  $_ | Out-String | Set-Content -LiteralPath (Join-Path $results 'harness-error.txt') -Encoding UTF8
  Add-Content -LiteralPath $summary -Value ('STOPPED: ' + $_.Exception.Message) -Encoding UTF8
  Write-Error $_
  exit 1
}
