#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$BuildDir,
    [string]$PackageDir,
    [string]$Node,
    [string]$Base = (Join-Path $env:LOCALAPPDATA ('WritSmoke-' + [guid]::NewGuid().ToString('N'))),
    [switch]$InteractiveNotepad
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Native Windows required: WSL, Wine and model tests do not qualify.' }
if (Test-Path -LiteralPath $Base) { throw 'Smoke Base must not exist; this test only owns newly created resources.' }
if ([bool]$BuildDir -eq [bool]$PackageDir) { throw 'Specify exactly one of BuildDir or PackageDir.' }
if ($PackageDir) {
    $exe = [IO.Path]::GetFullPath((Join-Path $PackageDir 'writ-cloud.exe'))
    $module = [IO.Path]::GetFullPath((Join-Path $PackageDir 'public-sync.mjs'))
    $bridge = [IO.Path]::GetFullPath((Join-Path $PackageDir 'node-policy.mjs'))
    if (-not $Node) { $Node = [IO.Path]::GetFullPath((Join-Path $PackageDir 'node.exe')) }
} else {
    $exe = [IO.Path]::GetFullPath((Join-Path $BuildDir 'Release\writ-cloud.exe'))
    $module = [IO.Path]::GetFullPath((Join-Path $BuildDir 'public-sync.mjs'))
    $bridge = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\runtime\node-policy.mjs'))
    if (-not $Node) { $Node = (Get-Command node -ErrorAction Stop).Source }
}
foreach ($path in @($exe, $module, $bridge, $Node)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing $path" }
}
[IO.Directory]::CreateDirectory($Base) | Out-Null
$store = Join-Path $Base 'store'
$providers = [Collections.Generic.List[object]]::new()
$roots = [Collections.Generic.HashSet[string]]::new()
$transcript = Join-Path $Base 'transcript.txt'
Start-Transcript -Path $transcript | Out-Null

function Assert($Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    Write-Host "PASS: $Name"
}
function EqualBytes([byte[]]$A, [byte[]]$B) {
    [Convert]::ToBase64String($A) -ceq [Convert]::ToBase64String($B)
}
function FilePath($P) { Join-Path $P.Root 'hello.txt' }
function Read-Log([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        # The provider keeps stdout open for writing. A reader must explicitly
        # share that access; File.ReadAllText's read-only sharing rejects it.
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = [IO.StreamReader]::new($stream)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    return ''
}
function LogText($P) { Read-Log $P.Log }
function Wait-Until([scriptblock]$Check, [string]$Name, $P) {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        if ($P -and $P.Process.HasExited) {
            throw "Provider exited ($($P.Process.ExitCode)): $(LogText $P) $(Read-Log $P.Error)"
        }
        if (& $Check) { Write-Host "PASS: $Name"; return }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timeout: $Name; $(if ($P) { LogText $P })"
}
function Inspect($P) {
    $json = & $exe inspect $P.Root
    if ($LASTEXITCODE) { throw 'Native placeholder inspection failed.' }
    $json | ConvertFrom-Json
}
function Start-Provider([string]$Name, [switch]$FailWriteback) {
    $root = Join-Path $Base $Name
    $tag = [guid]::NewGuid().ToString('N')
    $log = Join-Path $Base "$Name-$tag.out.txt"
    $err = Join-Path $Base "$Name-$tag.err.txt"
    $values = @('serve', $root, $store, $Node, $bridge, $module)
    if ($FailWriteback) { $values += '--fail-writeback' }
    # Start-Process joins ArgumentList on Windows. Quote each literal argument;
    # no shell is involved and all paths are rejected if quoting is ambiguous.
    foreach ($value in $values) {
        if ($value.Contains('"') -or $value.EndsWith('\')) { throw 'Invalid process argument.' }
    }
    $arguments = ($values | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $log -RedirectStandardError $err
    $p = [pscustomobject]@{ Root = $root; Process = $process; Log = $log; Error = $err }
    $providers.Add($p)
    $roots.Add($root) | Out-Null
    Wait-Until { (LogText $p).Contains('READY ') } "provider ready: $Name" $p
    return $p
}
function Crash-Provider($P) {
    # Deliberate provider process loss, not a clean shutdown or cache reuse.
    $P.Process.Kill()
    Assert ($P.Process.WaitForExit(10000)) 'provider terminated'
}
function Wait-Commit($P, [int]$After = 0) {
    Wait-Until { ([regex]::Matches((LogText $P), '(?m)^COMMIT ')).Count -gt $After } 'backing store committed and local edit marked in sync' $P
    Assert (Inspect $P).inSync 'native in-sync flag'
}
function Fresh-Read([string]$Name, [byte[]]$Expected) {
    $p = Start-Provider $Name
    $names = @(Get-ChildItem -LiteralPath $p.Root)
    Assert ($names.Count -eq 1 -and $names[0].Name -eq 'hello.txt') 'Explorer enumeration name'
    $info = Inspect $p
    Assert ($info.placeholder -and $info.size -eq $Expected.Length -and $info.onDisk -eq 0) 'logical size without payload allocation'
    Assert (-not [regex]::IsMatch((LogText $p), '(?m)^FETCH')) 'listing fetched zero payload bytes'
    Assert (EqualBytes ([IO.File]::ReadAllBytes((FilePath $p))) $Expected) 'fresh root hydrated exact persisted bytes'
    Wait-Until { (LogText $p).Contains('FETCH bytes=') } 'hydration callback observed' $p
    return $p
}
function Has-Recovery([byte[]]$Expected) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $store 'roots') -Filter '*.bin' -Recurse) {
        if (EqualBytes ([IO.File]::ReadAllBytes($file.FullName)) $Expected) { return $true }
    }
    return $false
}

$passed = $false
try {
    Write-Host "OS: $([Environment]::OSVersion.VersionString)"
    Write-Host "PowerShell: $($PSVersionTable.PSVersion); Node: $(& $Node --version)"
    Write-Host "Module SHA256: $((Get-FileHash -LiteralPath $module).Hash)"
    & $exe seed $store
    Assert ($LASTEXITCODE -eq 0) 'seed independent local backing store'
    $seed = [Text.Encoding]::UTF8.GetBytes("Hello from Writ!`r`nThis is public fixture data. Edit and save me in Notepad.`r`n")
    $first = Fresh-Read 'Writ' $seed
    if ($InteractiveNotepad) {
        $marker = 'Notepad saved ' + [guid]::NewGuid().ToString('N')
        Start-Process explorer.exe -ArgumentList ('"' + $first.Root + '"') | Out-Null
        Start-Process notepad.exe -ArgumentList ('"' + (FilePath $first) + '"') | Out-Null
        Write-Host "In the opened Notepad, replace the text with: $marker"
        Read-Host 'Press Ctrl+S, leave Notepad open, then press Enter here' | Out-Null
        $ordinary = [IO.File]::ReadAllBytes((FilePath $first))
        Assert ([IO.File]::ReadAllText((FilePath $first)).Contains($marker)) 'ordinary Notepad save reached NTFS'
    } else {
        $ordinary = [Text.Encoding]::UTF8.GetBytes("Ordinary save $([guid]::NewGuid())`r`n")
        [IO.File]::WriteAllBytes((FilePath $first), $ordinary)
        Write-Host 'NOTEPAD_SKIPPED: run with -InteractiveNotepad for the actual application gate.'
    }
    Wait-Commit $first
    if ($InteractiveNotepad) {
        Read-Host 'Commit verified while Notepad is open. Close that Notepad window, then press Enter' | Out-Null
    }
    Crash-Provider $first
    $second = Fresh-Read 'Writ-fresh' $ordinary

    $replacement = [Text.Encoding]::UTF8.GetBytes("ReplaceFile save $([guid]::NewGuid())`r`n")
    $temp = Join-Path $second.Root 'editor.tmp'
    [IO.File]::WriteAllBytes($temp, $replacement)
    [IO.File]::Replace($temp, (FilePath $second), $null)
    Wait-Commit $second
    Assert (Inspect $second).placeholder 'replacement converted back to a placeholder'
    Crash-Provider $second
    $third = Fresh-Read 'Writ-replaced' $replacement
    Crash-Provider $third

    $failure = Start-Provider 'Writ-replaced' -FailWriteback
    $uncommitted = [Text.Encoding]::UTF8.GetBytes("Recover this failed save $([guid]::NewGuid())`r`n")
    [IO.File]::WriteAllBytes((FilePath $failure), $uncommitted)
    Wait-Until { (LogText $failure).Contains('WRITEBACK_FAILED injected writeback failure') } 'failed writeback observed' $failure
    Assert (EqualBytes ([IO.File]::ReadAllBytes((FilePath $failure))) $uncommitted) 'failed writeback retains local edit'
    Assert (Has-Recovery $uncommitted) 'failed edit has an independent flushed recovery copy'
    Assert (-not (Inspect $failure).inSync) 'failed edit never marked in sync'
    Crash-Provider $failure
    $unchanged = Fresh-Read 'Writ-failure-check' $replacement
    Crash-Provider $unchanged

    $retry = Start-Provider 'Writ-replaced'
    Wait-Commit $retry
    Crash-Provider $retry
    $recovered = Fresh-Read 'Writ-recovered' $uncommitted
    Crash-Provider $recovered

    $a = Fresh-Read 'Writ-writer-A' $uncommitted
    $b = Fresh-Read 'Writ-writer-B' $uncommitted
    $winner = [Text.Encoding]::UTF8.GetBytes("Winning save $([guid]::NewGuid())`r`n")
    $conflict = [Text.Encoding]::UTF8.GetBytes("Stale-base edit $([guid]::NewGuid())`r`n")
    [IO.File]::WriteAllBytes((FilePath $a), $winner)
    Wait-Commit $a
    [IO.File]::WriteAllBytes((FilePath $b), $conflict)
    Wait-Until { (LogText $b).Contains('WRITEBACK_FAILED STALE_BASE') } 'stale base refused' $b
    Assert (EqualBytes ([IO.File]::ReadAllBytes((FilePath $b))) $conflict) 'conflicting local edit retained'
    Assert (Has-Recovery $conflict) 'conflicting edit recovery copy'
    Assert (-not (Inspect $b).inSync) 'conflict remains out of sync'
    Crash-Provider $a
    Crash-Provider $b
    $final = Fresh-Read 'Writ-conflict-check' $winner
    Crash-Provider $final
    $passed = $true
} finally {
    $cleanupErrors = @()
    foreach ($p in $providers) {
        if (-not $p.Process.HasExited) {
            & $exe stop $p.Root
            if (-not $p.Process.WaitForExit(10000)) { $p.Process.Kill(); $p.Process.WaitForExit() }
        }
    }
    foreach ($root in $roots) {
        & $exe remove $root $store
        if ($LASTEXITCODE) { $cleanupErrors += $root }
    }
    Write-Host "Evidence, backing store, local edits and recovery copies retained at $Base"
    if ($cleanupErrors.Count) { Write-Host "Removal failed for: $($cleanupErrors -join ', ')" }
    Stop-Transcript | Out-Null
    if ($cleanupErrors.Count) { throw 'Smoke cleanup did not complete; inspect the retained evidence.' }
}
if ($passed) { Write-Host "ALL CLOUD FILES SMOKE CHECKS PASSED (Notepad=$InteractiveNotepad)" }
