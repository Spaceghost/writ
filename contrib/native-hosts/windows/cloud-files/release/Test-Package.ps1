#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
$dist = Join-Path $OutputDir 'dist'
$logs = Join-Path $OutputDir 'logs'
$extract = Join-Path $OutputDir 'portable with spaces'
$installed = Join-Path $env:LOCALAPPDATA ('WritInstallTest-' + [guid]::NewGuid().ToString('N'))
$defaultRoot = Join-Path $env:USERPROFILE 'Writ'
$defaultData = Join-Path $env:LOCALAPPDATA 'WritDemo'
if ((Test-Path -LiteralPath $defaultRoot) -or (Test-Path -LiteralPath $defaultData)) { throw 'Install probe requires unused default Writ paths; existing user data is not touched.' }
function Assert($Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }; Write-Host "PASS: $Name"
}
function Check-Payload([string]$Path) {
    foreach ($line in Get-Content -LiteralPath (Join-Path $Path 'SHA256SUMS')) {
        $parts = $line -split '  ', 2
        if ($parts.Count -ne 2 -or $parts[1] -notmatch '^[A-Za-z0-9./-]+$' -or $parts[1].Contains('..') -or $parts[1].StartsWith('/')) { throw 'Invalid package manifest.' }
        Assert ((Get-FileHash -LiteralPath (Join-Path $Path $parts[1])).Hash.ToLowerInvariant() -ceq $parts[0]) "payload hash: $($parts[1])"
    }
}
Start-Transcript -Path (Join-Path $logs 'package-smoke.txt') | Out-Null
$provider = $null
try {
    Expand-Archive -LiteralPath (Get-Item (Join-Path $dist '*-portable.zip')).FullName -DestinationPath $extract
    Check-Payload $extract
    & (Join-Path $extract 'Smoke.ps1') -PackageDir $extract -Base (Join-Path $env:LOCALAPPDATA 'WritReleaseSmoke')
    # Reproduce the user's actual preview.2 upgrade, including its running CLI.
    $oldInstaller = Join-Path $OutputDir 'preview.2-setup.exe'
    Invoke-WebRequest -Uri 'https://github.com/Spaceghost/writ/releases/download/desktop-v0.1.0-preview.2/Writ-0.1.0-preview.2-windows-x64-setup.exe' -OutFile $oldInstaller
    Assert ((Get-FileHash -LiteralPath $oldInstaller).Hash.ToLowerInvariant() -ceq 'e8c2ee982bdab37f84f0a6e83c253437811322b9ce79d68b3123cf797684f34a') 'published preview.2 installer checksum'
    $oldInstall = Start-Process -FilePath $oldInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=`"$installed`"" -Wait -PassThru
    Assert ($oldInstall.ExitCode -eq 0) 'published preview.2 installs'
    $oldProvider = Start-Process -FilePath (Join-Path $installed 'writ-cloud.exe') -ArgumentList 'start' -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logs 'upgrade-provider.txt') -RedirectStandardError (Join-Path $logs 'upgrade-provider-errors.txt')
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        $oldReady = [bool]((Get-Content -LiteralPath (Join-Path $logs 'upgrade-provider.txt') -Raw) -match '(?m)^READY ')
        if (-not $oldReady) { Start-Sleep -Milliseconds 200 }
    } while (-not $oldReady -and -not $oldProvider.HasExited -and [DateTime]::UtcNow -lt $deadline)
    Assert $oldReady 'preview.2 provider is running during upgrade'
    $oldBytes = [IO.File]::ReadAllBytes((Join-Path $defaultRoot 'hello.txt'))
    $installer = (Get-Item (Join-Path $dist '*-setup.exe')).FullName
    $install = Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=`"$installed`" /LOG=`"$logs\install.txt`"" -Wait -PassThru
    Assert ($install.ExitCode -eq 0) 'installer succeeds'
    Assert ($oldProvider.WaitForExit(10000)) 'upgrade stops actual preview.2 provider'
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $defaultRoot 'hello.txt'))) -ceq [Convert]::ToBase64String($oldBytes)) 'upgrade retains hydrated data'
    Check-Payload $installed
    $exe = Join-Path $installed 'writ-cloud.exe'
    & $exe version
    Assert ($LASTEXITCODE -eq 0) 'installed executable starts'
    # Use only bundled dependencies and the default launch command.
    $provider = Start-Process -FilePath $exe -ArgumentList 'start' -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logs 'installed-provider.txt') -RedirectStandardError (Join-Path $logs 'installed-provider-errors.txt')
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        if ($provider.HasExited) { throw 'Installed provider exited; inspect installed-provider logs.' }
        # Empty startup logs can produce AutomationNull before the first write.
        # The match operator safely accepts an empty pipeline on all PS versions.
        $ready = [bool]((Get-Content -LiteralPath (Join-Path $logs 'installed-provider.txt') -Raw) -match '(?m)^READY ')
        if (-not $ready) { Start-Sleep -Milliseconds 200 }
    } while (-not $ready -and [DateTime]::UtcNow -lt $deadline)
    Assert $ready 'Start menu command creates default Writ root'
    $hello = Join-Path $defaultRoot 'hello.txt'
    $bytes = [IO.File]::ReadAllBytes($hello)
    Assert ($bytes.Length -gt 0) 'installed provider hydrates'
    & $exe stop
    Assert ($LASTEXITCODE -eq 0 -and $provider.WaitForExit(10000)) 'CLI provider stops before desktop test'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installed 'DesktopSmoke.ps1') -PackageDir $installed -OutputDir $logs -ProbeExe (Join-Path $OutputDir 'build-1\Release\writ-desktop-probe.exe')
    Assert ($LASTEXITCODE -eq 0) 'installed desktop UI and provider checks pass'
    $bytes = [IO.File]::ReadAllBytes($hello)
    & (Join-Path $installed 'node.exe') (Join-Path $installed 'drive\Lifecycle.mjs') $installed 'start'
    Assert ($LASTEXITCODE -eq 0) 'shared files and rules app starts through its native launcher'
    $desktop = Start-Process -FilePath (Join-Path $installed 'Writ.exe') -ArgumentList '--background' -PassThru
    Start-Sleep -Seconds 3
    Assert (-not $desktop.HasExited) 'background app stays running for uninstall test'
    $uninstall = Start-Process -FilePath (Join-Path $installed 'unins000.exe') -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=`"$logs\uninstall.txt`"" -Wait -PassThru
    Assert ($uninstall.ExitCode -eq 0) 'uninstaller succeeds while provider is running'
    & (Join-Path $extract 'node.exe') (Join-Path $extract 'drive\Lifecycle.mjs') $extract 'stopped'
    Assert ($LASTEXITCODE -eq 0) 'shared app stops and retains working files through uninstall'
    Assert ($provider.WaitForExit(10000)) 'uninstaller stops provider'
    Assert ($desktop.WaitForExit(10000)) 'uninstaller stops desktop application'
    Assert (-not (Test-Path -LiteralPath $exe)) 'application removed'
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($hello)) -ceq [Convert]::ToBase64String($bytes)) 'uninstall preserves hydrated user file'
    Assert (Test-Path -LiteralPath (Join-Path $defaultData 'store\head')) 'uninstall preserves backing store'
    $info = & (Join-Path $extract 'writ-cloud.exe') inspect $defaultRoot | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and -not $info.placeholder) 'uninstall unregisters placeholder'
    Write-Host 'ALL WINDOWS PACKAGE CHECKS PASSED'
} catch {
    Write-Host $_.ScriptStackTrace
    throw
} finally {
    if ($provider -and -not $provider.HasExited) {
        & (Join-Path $extract 'writ-cloud.exe') stop
        if (-not $provider.WaitForExit(10000)) { $provider.Kill(); $provider.WaitForExit() }
    }
    Stop-Transcript | Out-Null
}
