#requires -Version 7.4
param([Parameter(Mandatory)][string]$PackageDir, [Parameter(Mandatory)][string]$OutputDir, [Parameter(Mandatory)][string]$ProbeExe)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WritCloudWindow {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int max);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
}
'@
function Assert($Condition, [string]$Name) { if (-not $Condition) { throw "FAIL: $Name" }; Write-Host "PASS: $Name" }
function Wait-For([scriptblock]$Condition, [string]$Name) {
    $until = [DateTime]::UtcNow.AddSeconds(90)
    do { if (& $Condition) { Write-Host "PASS: $Name"; return }; Start-Sleep -Milliseconds 200 } while ([DateTime]::UtcNow -lt $until)
    throw "Timeout: $Name"
}
function Text([IntPtr]$Handle) {
    $text = [Text.StringBuilder]::new(4096); [void][WritCloudWindow]::GetWindowText($Handle, $text, $text.Capacity); $text.ToString()
}
function Status { Text ([WritCloudWindow]::GetDlgItem($script:window, 204)) }
function Invoke([int]$Id) {
    & $ProbeExe invoke ([WritCloudWindow]::GetDlgItem($script:window, $Id)).ToInt64()
    if ($LASTEXITCODE) { throw "Native accessibility invocation failed: $Id" }
}
function Snapshot([IntPtr]$Handle, [string]$Name) {
    & $ProbeExe dump $Handle.ToInt64() | Set-Content (Join-Path $OutputDir "$Name-ui.json")
    if ($LASTEXITCODE) { throw 'Cloud accessibility inspection failed.' }
    $rect = [WritCloudWindow+Rect]::new(); [void][WritCloudWindow]::GetWindowRect($Handle, [ref]$rect)
    $bitmap = [Drawing.Bitmap]::new($rect.Right-$rect.Left, $rect.Bottom-$rect.Top)
    $graphics = [Drawing.Graphics]::FromImage($bitmap); $dc = $graphics.GetHdc()
    try { Assert ([WritCloudWindow]::PrintWindow($Handle, $dc, 2)) 'Cloud window screenshot captured' }
    finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
    try { $bitmap.Save((Join-Path $OutputDir "$Name.png"), [Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
}
$root = Join-Path $env:USERPROFILE 'Writ Cloud'
if (Test-Path $root) { throw 'Cloud desktop fixture requires an unused default cloud folder.' }
$app = $null; $script:window = [IntPtr]::Zero
try {
    $app = Start-Process (Join-Path $PackageDir 'Writ.exe') -PassThru
    Wait-For { $script:window = [WritCloudWindow]::FindWindow('WritDesktop.7DDDA5C1', 'Writ'); $script:window -ne [IntPtr]::Zero } 'Cloud desktop appears'
    Wait-For { (Status) -eq 'Files are up to date' } 'Desktop completes initial remote folder hydration'
    Assert (Test-Path (Join-Path $root 'large.bin')) 'Desktop owns real multi-file remote sync'
    Assert ((Text ([WritCloudWindow]::GetDlgItem($script:window, 203))) -match 'S3-compatible folder sync') 'Remote scope shown in desktop'
    Snapshot $script:window 'cloud-ready'
    Invoke 103
    Wait-For { (Status) -eq 'Syncing paused' } 'Cloud pause waits for provider exit'
    [IO.File]::WriteAllText((Join-Path $root 'desktop-created.txt'), 'Saved through cloud desktop')
    Invoke 103
    Wait-For { (Status) -eq 'Files are up to date' } 'Cloud resume publishes offline desktop edit'
    & $ProbeExe settings ([WritCloudWindow]::GetDlgItem($script:window, 110)).ToInt64()
    if ($LASTEXITCODE) { throw 'Cannot select accessible Settings tab.' }
    Invoke 111
    Wait-For { [WritCloudWindow]::FindWindow('WritConnection.7DDDA5C1', 'Writ — Connect storage') -ne [IntPtr]::Zero } 'Storage settings open after graceful pause'
    $connection = [WritCloudWindow]::FindWindow('WritConnection.7DDDA5C1', 'Writ — Connect storage')
    Assert ((Text ([WritCloudWindow]::GetDlgItem($connection, 420))).StartsWith('https://localhost:')) 'Storage form shows configured endpoint'
    Assert ((Text ([WritCloudWindow]::GetDlgItem($connection, 425))).Length -eq 0) 'Stored secret is not exposed in storage form'
    Snapshot $connection 'cloud-connection'
    & $ProbeExe value ([WritCloudWindow]::GetDlgItem($connection, 424)).ToInt64() 'writ-native-fixture'
    if ($LASTEXITCODE) { throw 'Cannot fill fixture access ID through UI Automation.' }
    & $ProbeExe value ([WritCloudWindow]::GetDlgItem($connection, 425)).ToInt64() 'public-disposable-fixture-secret'
    if ($LASTEXITCODE) { throw 'Cannot fill fixture secret through UI Automation.' }
    & $ProbeExe invoke ([WritCloudWindow]::GetDlgItem($connection, 1)).ToInt64()
    if ($LASTEXITCODE) { throw 'Cannot submit storage connection through UI Automation.' }
    Wait-For { (Status) -eq 'Files are up to date' } 'Connect form saves credentials and starts real cloud sync'
    Invoke 111
    Wait-For { [WritCloudWindow]::FindWindow('WritConnection.7DDDA5C1', 'Writ — Connect storage') -ne [IntPtr]::Zero } 'Storage settings reopen'
    $connection = [WritCloudWindow]::FindWindow('WritConnection.7DDDA5C1', 'Writ — Connect storage')
    [void][WritCloudWindow]::PostMessage($connection, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
    Wait-For { (Status) -eq 'Syncing paused' } 'Cancel storage settings leaves sync paused'
    Invoke 103
    Wait-For { (Status) -eq 'Files are up to date' } 'Existing cloud connection resumes'
    & (Join-Path $PackageDir 'Writ.exe') --quit
    Assert ($LASTEXITCODE -eq 0) 'Cloud desktop quits gracefully'
    Assert ($app.WaitForExit(10000)) 'Cloud desktop process exits'
    Assert ([IO.File]::ReadAllText((Join-Path $root 'desktop-created.txt')) -eq 'Saved through cloud desktop') 'Cloud quit retains offline files'
} finally {
    if ($app -and -not $app.HasExited) {
        & (Join-Path $PackageDir 'Writ.exe') --quit
        if (-not $app.WaitForExit(10000)) { $app.Kill($true) }
    }
}
