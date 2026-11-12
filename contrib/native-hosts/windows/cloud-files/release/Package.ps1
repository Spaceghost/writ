#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PolicyDir,
    [Parameter(Mandatory)][string]$OutputDir
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows) { throw 'Build on native Windows x64 with MSVC.' }
$repo = (& git -C $PSScriptRoot rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE) { throw 'A Git checkout is required.' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if ($OutputDir.StartsWith($repo.Replace('/', '\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Build outside the checkout.' }
if (Test-Path -LiteralPath $OutputDir) { throw 'OutputDir must be new; no existing build is reused.' }
$PolicyDir = (Resolve-Path -LiteralPath $PolicyDir).Path
$commit = (& git -C $repo rev-parse HEAD).Trim()
$version = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+-preview\.\d+$') { throw 'Only explicitly versioned previews are supported.' }
if ($commit -notmatch '^[0-9a-f]{40}$') { throw 'Invalid source revision.' }
$pins = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchains.json') -Raw | ConvertFrom-Json
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
foreach ($line in Get-Content -LiteralPath (Join-Path $repo 'verification\source-sha256.txt')) {
    $parts = $line -split '  ', 2
    if ($parts.Count -ne 2 -or (Hash (Join-Path $repo $parts[1])) -cne $parts[0]) {
        throw "Source manifest mismatch: $line. Check out with core.autocrlf=false."
    }
}
function Download($Pin, [string]$Path) {
    Invoke-WebRequest -Uri $Pin.url -OutFile $Path
    if ((Hash $Path) -cne $Pin.sha256) { throw "Dependency checksum mismatch: $($Pin.url)" }
}
foreach ($line in Get-Content -LiteralPath (Join-Path $PolicyDir 'SHA256SUMS')) {
    $parts = $line -split '  ', 2
    if ($parts.Count -ne 2 -or $parts[1] -notin @('public-sync.mjs', 'public-sync-tests.js', 'directory-sync.mjs', 'directory-namespace.mjs', 'directory-sync-tests.js', 'directory-namespace-tests.js', 'stream-tests.js', 'drive.mjs', 'drive-tests.js', 'commit.txt', 'bend-version.txt')) { throw 'Invalid policy manifest.' }
    if ((Hash (Join-Path $PolicyDir $parts[1])) -cne $parts[0]) { throw 'Policy checksum mismatch.' }
}
if ((Get-Content -LiteralPath (Join-Path $PolicyDir 'commit.txt')) -cne $commit) { throw 'Policy came from another source commit.' }
$logs = New-Item -ItemType Directory -Path (Join-Path $OutputDir 'logs')
$dist = New-Item -ItemType Directory -Path (Join-Path $OutputDir 'dist')
$payload = New-Item -ItemType Directory -Path (Join-Path $OutputDir 'payload')
Download $pins.node (Join-Path $OutputDir 'node.zip')
Expand-Archive -LiteralPath (Join-Path $OutputDir 'node.zip') -DestinationPath (Join-Path $OutputDir 'node')
$nodeDir = Join-Path $OutputDir "node\node-v$($pins.node.version)-win-x64"
Copy-Item -LiteralPath (Join-Path $nodeDir 'node.exe') -Destination $payload
Copy-Item -LiteralPath (Join-Path $nodeDir 'LICENSE') -Destination (Join-Path $payload 'NODE-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $PolicyDir 'public-sync.mjs') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PolicyDir 'directory-sync.mjs') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PolicyDir 'directory-namespace.mjs') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\runtime\node-policy.mjs') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\Smoke.ps1') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\DesktopSmoke.ps1') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.txt') -Destination $payload
$drive = New-Item -ItemType Directory -Path (Join-Path $payload 'drive')
$driveSource = Join-Path $repo 'contrib\native-hosts\drive'
foreach ($name in 'app.mjs', 'broker.mjs', 'policy.mjs', 's3.mjs', 'Smoke.mjs', 'Lifecycle.mjs') {
    Copy-Item -LiteralPath (Join-Path $driveSource $name) -Destination $drive
}
Copy-Item -LiteralPath (Join-Path $driveSource 'ui') -Destination $drive -Recurse
foreach ($name in 'drive.mjs', 'directory-sync.mjs') { Copy-Item -LiteralPath (Join-Path $PolicyDir $name) -Destination $drive }
& (Join-Path $payload 'node.exe') (Join-Path $PolicyDir 'drive-tests.js') 2>&1 | Tee-Object -FilePath (Join-Path $logs 'windows-drive-model.txt')
if ($LASTEXITCODE) { throw 'Drive model failed on bundled Windows Node.' }
& (Join-Path $payload 'node.exe') (Join-Path $PolicyDir 'public-sync-tests.js') 2>&1 | Tee-Object -FilePath (Join-Path $logs 'windows-model.txt')
if ($LASTEXITCODE) { throw 'Bend model failed on bundled Windows Node.' }
foreach ($suite in 'directory-sync-tests', 'directory-namespace-tests', 'stream-tests') {
    & (Join-Path $payload 'node.exe') (Join-Path $PolicyDir "$suite.js") 2>&1 | Tee-Object -FilePath (Join-Path $logs "windows-$suite.txt")
    if ($LASTEXITCODE) { throw "Bend $suite failed on bundled Windows Node." }
}
foreach ($pass in 1, 2) {
    $build = Join-Path $OutputDir "build-$pass"
    & cmake -S (Join-Path $PSScriptRoot '..') -B $build -G $pins.cmakeGenerator -A x64 -T $pins.msvcToolset `
        "-DCMAKE_SYSTEM_VERSION=$($pins.windowsSdk)" "-DWRIT_VERSION=$version" "-DWRIT_SOURCE_COMMIT=$commit" 2>&1 |
        Tee-Object -FilePath (Join-Path $logs "configure-$pass.txt")
    if ($LASTEXITCODE) { throw "CMake configure $pass failed." }
    & cmake --build $build --config Release --parallel 2 2>&1 | Tee-Object -FilePath (Join-Path $logs "build-$pass.txt")
    if ($LASTEXITCODE) { throw "MSVC build $pass failed." }
}
foreach ($executable in 'writ-cloud.exe', 'Writ.exe', 'writ-sync.exe', 'WritDrive.exe') {
    $first = Join-Path $OutputDir "build-1\Release\$executable"
    $second = Join-Path $OutputDir "build-2\Release\$executable"
    if ((Hash $first) -cne (Hash $second)) { throw "Two clean builds differ: $executable" }
    Copy-Item -LiteralPath $first -Destination $payload
}
& (Join-Path $payload 'writ-cloud.exe') version | Tee-Object -FilePath (Join-Path $logs 'version.txt')
if ($LASTEXITCODE) { throw 'Built executable did not start.' }
$info = [ordered]@{
    version = $version
    sourceCommit = $commit
    sourceManifestSha256 = Hash (Join-Path $repo 'verification\source-sha256.txt')
    dependencies = $pins
    nativeToolchain = @(Get-Content -LiteralPath (Join-Path $OutputDir 'build-1\writ-toolchain.txt'))
    runnerImage = "$env:ImageOS $env:ImageVersion".Trim()
    powershell = $PSVersionTable.PSVersion.ToString()
    nativeRebuildSha256 = Hash (Join-Path $payload 'writ-cloud.exe')
    desktopRebuildSha256 = Hash (Join-Path $payload 'Writ.exe')
    directoryRebuildSha256 = Hash (Join-Path $payload 'writ-sync.exe')
    driveRebuildSha256 = Hash (Join-Path $payload 'WritDrive.exe')
    profile = 'Shared Linux/Windows S3 files-and-rules app; Windows tray/folder sync and local Cloud Files preview also included; unsigned; protected desktop confinement unqualified'
}
$info | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $payload 'BUILD-INFO.json') -Encoding utf8NoBOM
Get-ChildItem -LiteralPath $payload -File -Recurse | Sort-Object FullName | ForEach-Object { "$(Hash $_.FullName)  $([IO.Path]::GetRelativePath($payload, $_.FullName).Replace('\', '/'))" } |
    Set-Content -LiteralPath (Join-Path $payload 'SHA256SUMS') -Encoding ascii
Download $pins.inno (Join-Path $OutputDir 'inno-setup.exe')
$innoDir = Join-Path $OutputDir 'inno'
$install = Start-Process -FilePath (Join-Path $OutputDir 'inno-setup.exe') -ArgumentList `
    "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /CURRENTUSER /DIR=`"$innoDir`"" -Wait -PassThru
if ($install.ExitCode) { throw "Inno compiler installation failed ($($install.ExitCode))." }
$numeric = ($version -split '-')[0] + '.0'
$stamp = [DateTimeOffset]::FromUnixTimeSeconds([long](& git -C $repo show -s --format=%ct HEAD))
function Make-Zip([string]$Path) {
    $zip = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $payload -File -Recurse | Sort-Object FullName) {
            $entry = $zip.CreateEntry([IO.Path]::GetRelativePath($payload, $file.FullName).Replace('\', '/'), [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $stamp
            $inputFile = $file.OpenRead(); $outputFile = $entry.Open()
            try { $inputFile.CopyTo($outputFile) } finally { $outputFile.Dispose(); $inputFile.Dispose() }
        }
    } finally { $zip.Dispose() }
}
$base = "Writ-$version-windows-x64"
foreach ($pass in 1, 2) {
    $packageOut = New-Item -ItemType Directory -Path (Join-Path $OutputDir "package-$pass")
    Make-Zip (Join-Path $packageOut "$base-portable.zip")
    & (Join-Path $innoDir 'ISCC.exe') "/DPayload=$payload" "/DVersion=$version" "/DNumericVersion=$numeric" "/O$packageOut" `
        (Join-Path $PSScriptRoot 'Writ.iss') 2>&1 | Tee-Object -FilePath (Join-Path $logs "installer-$pass.txt")
    if ($LASTEXITCODE) { throw "Installer compile $pass failed." }
}
foreach ($name in "$base-portable.zip", "$base-setup.exe") {
    $one = Join-Path $OutputDir "package-1\$name"; $two = Join-Path $OutputDir "package-2\$name"
    if ((Hash $one) -cne (Hash $two)) { throw "Repeated package differs: $name" }
    Copy-Item -LiteralPath $one -Destination $dist
    "MATCH $(Hash $one) $name" | Tee-Object -FilePath (Join-Path $logs 'reproducibility.txt') -Append
}
Copy-Item -LiteralPath (Join-Path $payload 'BUILD-INFO.json') -Destination $dist
Write-Host "Packages built at $dist. Native and install smoke tests must pass before publication."
