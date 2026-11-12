#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDir, [Parameter(Mandatory)][string]$OutputDir, [Parameter(Mandatory)][string]$ProbeExe)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'This fixture provisions trust only on disposable GitHub-hosted Windows runners.' }
$settings = 'HKCU:\Software\Writ\S3'
if (Test-Path $settings) { throw 'S3 acceptance requires a disposable account without Writ S3 settings.' }
$base = Join-Path $env:USERPROFILE ('WritS3Smoke-' + [Guid]::NewGuid().ToString('N'))
$fixture = Join-Path $base 'fixture'
New-Item -ItemType Directory $base,$fixture,$OutputDir -Force | Out-Null
$exe = Join-Path $PackageDir 'writ-sync.exe'
$server = $null; $certificate = $null; $credentialTarget = $null; $number = 0
Start-Transcript -Path (Join-Path $OutputDir 'directory-smoke.txt') | Out-Null
function Assert($Condition, [string]$Name) { if (-not $Condition) { throw "FAIL: $Name" }; Write-Host "PASS: $Name" }
function Wait-For([scriptblock]$Condition, [string]$Name, [int]$Seconds = 40) {
    $end = [DateTime]::UtcNow.AddSeconds($Seconds)
    do { if (& $Condition) { Write-Host "PASS: $Name"; return }; Start-Sleep -Milliseconds 100 } while ([DateTime]::UtcNow -lt $end)
    throw "Timeout: $Name"
}
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Client([string]$Name, [bool]$Expected = $true) {
    $script:number++
    $root = Join-Path $base $Name; $state = Join-Path $base "$Name-state"
    $process = Start-Process -FilePath $exe -ArgumentList @('once', "`"$root`"", "`"$state`"") -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $OutputDir "directory-$script:number-$Name.txt") -RedirectStandardError (Join-Path $OutputDir "directory-$script:number-$Name.err.txt")
    if (-not $process.WaitForExit(180000)) { $process.Kill($true); throw "Client $Name timed out" }
    Assert (($process.ExitCode -eq 0) -eq $Expected) "Client $Name expected exit ($($process.ExitCode))"
}
function Background-Client([string]$Name) {
    $script:number++
    Start-Process -FilePath $exe -ArgumentList @('once', "`"$(Join-Path $base $Name)`"", "`"$(Join-Path $base "$Name-state")`"") -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $OutputDir "directory-$script:number-$Name.txt") -RedirectStandardError (Join-Path $OutputDir "directory-$script:number-$Name.err.txt")
}
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WritFixtureCredentials {
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool CredDelete(string name, uint type, uint flags);
}
'@
try {
    $openssl = (Get-Command openssl.exe).Source
    & $openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost' `
        -keyout (Join-Path $fixture 'private.pem') -out (Join-Path $fixture 'certificate.pem') 2>&1 | Out-File (Join-Path $OutputDir 'fixture-tls.txt')
    if ($LASTEXITCODE) { throw 'Cannot create fixture TLS certificate.' }
    # CurrentUser Root imports display a Win32 consent dialog in unattended CI.
    # The disposable runner's machine store supports unattended provisioning;
    # the exact generated certificate is removed in finally. TLS stays strict.
    $certificate = Import-Certificate -FilePath (Join-Path $fixture 'certificate.pem') -CertStoreLocation Cert:\LocalMachine\Root
    Write-Host 'PASS: disposable fixture certificate trusted without changing application TLS validation'
    $server = Start-Process python -ArgumentList @("`"$(Join-Path $PSScriptRoot 's3_fixture.py')`"", "`"$fixture`"") -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $OutputDir 'fixture-server.txt') -RedirectStandardError (Join-Path $OutputDir 'fixture-server.err.txt')
    Wait-For { Test-Path (Join-Path $fixture 'ready.json') } 'HTTPS S3 fixture ready'
    $endpoint = (Get-Content (Join-Path $fixture 'ready.json') -Raw | ConvertFrom-Json).endpoint
    $info = [Diagnostics.ProcessStartInfo]::new($exe, 'configure-stdin')
    $info.UseShellExecute = $false; $info.RedirectStandardInput = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $configure = [Diagnostics.Process]::Start($info)
    $configure.StandardInput.Write("$endpoint`nwrit-test`nwrit`nauto`nwrit-native-fixture`npublic-disposable-fixture-secret`n`n")
    $configure.StandardInput.Close(); $configure.WaitForExit()
    Assert ($configure.ExitCode -eq 0) 'Connection and credentials saved through native CLI'
    $identity = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("$endpoint`nwrit-test`nwrit`nauto`n"))
    $credentialTarget = 'Writ/S3/' + [Convert]::ToHexString($identity).ToLowerInvariant()
    $a = Join-Path $base 'A'; $b = Join-Path $base 'B'
    New-Item -ItemType Directory (Join-Path $a 'notes'),(Join-Path $a 'empty') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $a 'notes\hello.txt'), 'first version')
    [IO.File]::WriteAllText((Join-Path $a 'notes\café.txt'), 'Unicode filename')
    [IO.File]::WriteAllText((Join-Path $a 'delete.txt'), 'keep a recovery copy')
    $binary = [byte[]]::new(1048577)
    for ($i=0; $i -lt $binary.Length; $i++) { $binary[$i] = [byte]($i % 251) }
    [IO.File]::WriteAllBytes((Join-Path $a 'large.bin'), $binary)
    Client A; Client B
    Assert ((Hash (Join-Path $a 'large.bin')) -eq (Hash (Join-Path $b 'large.bin'))) 'Multi-chunk binary download matches independent SHA-256'
    Assert ([IO.File]::ReadAllText((Join-Path $b 'notes\café.txt')) -eq 'Unicode filename') 'Unicode nested filename round trips'
    Assert (Test-Path (Join-Path $b 'empty') -PathType Container) 'Empty directory syncs'
    [IO.File]::WriteAllText((Join-Path $a 'notes\hello.txt'), 'offline edit')
    Remove-Item (Join-Path $a 'delete.txt')
    Rename-Item (Join-Path $a 'notes\café.txt') 'renamed.txt'
    Client A; Client B
    Assert ([IO.File]::ReadAllText((Join-Path $b 'notes\hello.txt')) -eq 'offline edit') 'Offline edit downloads'
    Assert (-not (Test-Path (Join-Path $b 'delete.txt'))) 'Remote deletion removes only unchanged local file'
    Assert (Test-Path (Join-Path $b 'notes\renamed.txt')) 'Rename creates destination'
    Assert (-not (Test-Path (Join-Path $b 'notes\café.txt'))) 'Rename tombstones source'
    Assert (@(Get-ChildItem (Join-Path $base 'B-state\Recovery') -File).Count -ge 3) 'Replaced and deleted files have recovery copies'
    [IO.File]::WriteAllText((Join-Path $a 'notes\hello.txt'), 'remote competing edit')
    [IO.File]::WriteAllText((Join-Path $b 'notes\hello.txt'), 'local competing edit')
    Client A; Client B $false
    Assert ([IO.File]::ReadAllText((Join-Path $b 'notes\hello.txt')) -eq 'local competing edit') 'Conflict preserves local bytes'
    [IO.File]::WriteAllText((Join-Path $b 'notes\hello.txt'), 'remote competing edit'); Client B
    [IO.File]::WriteAllText((Join-Path $a 'notes\hello.txt'), 'download must verify'); Client A
    New-Item -ItemType File (Join-Path $fixture 'corrupt') | Out-Null
    Client B $false
    Assert ([IO.File]::ReadAllText((Join-Path $b 'notes\hello.txt')) -eq 'remote competing edit') 'Corrupt remote body cannot replace local data'
    Remove-Item (Join-Path $fixture 'corrupt'); Client B
    [IO.File]::WriteAllText((Join-Path $a 'notes\hello.txt'), 'retry after write failure')
    New-Item -ItemType File (Join-Path $fixture 'fail-write') | Out-Null
    Client A $false
    Assert ([IO.File]::ReadAllText((Join-Path $a 'notes\hello.txt')) -eq 'retry after write failure') 'Failed manifest publication retains edited file'
    Remove-Item (Join-Path $fixture 'fail-write'); Client A; Client B
    # Delay the remote body after B hashes its local file, then hold a real writer.
    [IO.File]::WriteAllText((Join-Path $a 'notes\hello.txt'), 'remote while editor opens'); Client A
    New-Item -ItemType File (Join-Path $fixture 'hold-get') | Out-Null
    $race = Background-Client B
    Wait-For { Test-Path (Join-Path $fixture 'hold-get.blocked') } 'Download reached deterministic local-race barrier'
    $writer = [IO.File]::Open((Join-Path $b 'notes\hello.txt'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes('editor retains this version'); $writer.SetLength(0); $writer.Write($bytes); $writer.Flush($true)
        New-Item -ItemType File (Join-Path $fixture 'hold-get.release') | Out-Null
        Assert ($race.WaitForExit(60000)) 'Writer-race client exits'
        Assert ($race.ExitCode -ne 0) 'Already-open writer blocks remote replacement'
    } finally { $writer.Dispose() }
    Assert ([IO.File]::ReadAllText((Join-Path $b 'notes\hello.txt')) -eq 'editor retains this version') 'Open writer bytes survive download race'
    [IO.File]::WriteAllText((Join-Path $b 'notes\hello.txt'), 'remote while editor opens'); Client B
    # Both clients start from the same baseline; A loses a real conditional PUT.
    [IO.File]::WriteAllText((Join-Path $a 'notes\hello.txt'), 'A concurrent publish')
    [IO.File]::WriteAllText((Join-Path $b 'notes\hello.txt'), 'B concurrent publish')
    New-Item -ItemType File (Join-Path $fixture 'hold-put') | Out-Null
    $competing = Background-Client A
    Wait-For { Test-Path (Join-Path $fixture 'hold-put.blocked') } 'A reached conditional publication barrier'
    Client B
    New-Item -ItemType File (Join-Path $fixture 'hold-put.release') | Out-Null
    Assert ($competing.WaitForExit(60000)) 'Competing publisher exits'
    Assert ($competing.ExitCode -ne 0) 'Losing conditional publisher reports conflict'
    Assert (Test-Path (Join-Path $fixture 'cas-rejected')) 'Independent S3 oracle rejected stale If-Match'
    Assert ([IO.File]::ReadAllText((Join-Path $a 'notes\hello.txt')) -eq 'A concurrent publish') 'Losing publisher keeps its local version'
    $outside = Join-Path $base 'outside'; New-Item -ItemType Directory $outside | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $b 'linked') -Target $outside | Out-Null
    Client B $false
    Assert (@(Get-ChildItem $outside -Force).Count -eq 0) 'Reparse target untouched'
    Assert ([int](Get-Content (Join-Path $fixture 'verified.txt')) -gt 20) 'Real HTTPS requests independently authenticated with SigV4'
    & (Join-Path $PSScriptRoot 'DesktopSmoke.ps1') -PackageDir $PackageDir -OutputDir $OutputDir -ProbeExe $ProbeExe
    Client C
    Assert ([IO.File]::ReadAllText((Join-Path $base 'C\desktop-created.txt')) -eq 'Saved through cloud desktop') 'A new client retrieves the desktop app save'
    $manifestKey = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes('/writ-test/writ/manifest.writ'))).ToLowerInvariant()
    $manifestPath = Join-Path $fixture "objects\$manifestKey"
    Move-Item $manifestPath ($manifestPath + '.missing')
    try {
        Client C $false
        Assert (Test-Path (Join-Path $base 'C\desktop-created.txt')) 'Missing established manifest cannot remove working files'
    } finally { Move-Item ($manifestPath + '.missing') $manifestPath }
    Rename-Item (Join-Path $base 'C') 'C-retained'
    New-Item -ItemType Directory (Join-Path $base 'C') | Out-Null
    Client C $false
    Assert ([IO.File]::ReadAllText((Join-Path $base 'C-retained\desktop-created.txt')) -eq 'Saved through cloud desktop') 'Replacement root identity cannot reuse previous baseline'
    Write-Host 'PASS: native directory and S3 protocol acceptance complete; actual Cloudflare R2 account test is separate.'
} finally {
    if ($server -and -not $server.HasExited) { $server.Kill($true); $server.WaitForExit() }
    if ($certificate) { Remove-Item -LiteralPath "Cert:\LocalMachine\Root\$($certificate.Thumbprint)" }
    if ($credentialTarget) { [void][WritFixtureCredentials]::CredDelete($credentialTarget, 1, 0) }
    if (Test-Path $settings) { Remove-Item -LiteralPath $settings -Recurse }
    Stop-Transcript | Out-Null
}
