#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageDir,
    [Parameter(Mandatory)][string]$OutputDir
)
# Run with Windows PowerShell: its built-in UI Automation assemblies drive real
# standard controls. No test-only commands are added to the application.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, UIAutomationClientsideProviders, System.Drawing
# Windows PowerShell's hosted automation client can otherwise expose only
# generic HWND panes. Register Microsoft's standard Win32 proxy assembly.
$proxies = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'UIAutomationClientsideProviders' } | Select-Object -First 1
[Windows.Automation.ClientSettings]::RegisterClientSideProviderAssembly($proxies.GetName())
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WritWindow {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int max);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
  [DllImport("shell32.dll")] static extern int Shell_NotifyIconGetRect(ref IconIdentifier id, out Rect rect);
  [StructLayout(LayoutKind.Sequential)] struct IconIdentifier { public uint cbSize; public IntPtr hWnd; public uint id; public Guid guid; }
  public static bool TrayIconExists(IntPtr window) {
    var id = new IconIdentifier { cbSize=(uint)Marshal.SizeOf(typeof(IconIdentifier)), hWnd=window, id=1,
      guid=new Guid("7ddda5c1-3eb0-4f92-aca4-916b35912004") };
    Rect rect; return Shell_NotifyIconGetRect(ref id, out rect) == 0 && rect.Right > rect.Left;
  }
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
}
'@
$app = $null
$script:window = [IntPtr]::Zero
$exe = Join-Path $PackageDir 'Writ.exe'
$cli = Join-Path $PackageDir 'writ-cloud.exe'
$root = Join-Path $env:USERPROFILE 'Writ'
$hello = Join-Path $root 'hello.txt'
$log = Join-Path $env:LOCALAPPDATA 'WritDemo\desktop\activity.log'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$existingStartup = (Get-ItemProperty -LiteralPath $runKey -Name Writ -ErrorAction SilentlyContinue)
if ($existingStartup) { throw 'Desktop probe requires no existing Writ sign-in entry.' }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Start-Transcript -Path (Join-Path $OutputDir 'desktop-smoke.txt') | Out-Null
function Assert($Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }; Write-Host "PASS: $Name"
}
function Wait-For([scriptblock]$Condition, [string]$Name, [int]$Seconds = 35) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        if (& $Condition) { Write-Host "PASS: $Name"; return }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "FAIL: timed out: $Name"
}
function Text([int]$Id) {
    $buffer = New-Object Text.StringBuilder 4096
    [void][WritWindow]::GetWindowText([WritWindow]::GetDlgItem($script:window, $Id), $buffer, $buffer.Capacity)
    return $buffer.ToString()
}
function Element([int]$Id) {
    $handle = [WritWindow]::GetDlgItem($script:window, $Id)
    if ($handle -eq [IntPtr]::Zero) { throw "Missing native control $Id" }
    return [Windows.Automation.AutomationElement]::FromHandle($handle)
}
function Invoke-Control([int]$Id) {
    $pattern = (Element $Id).GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
    $pattern.Invoke()
}
function Toggle-Startup {
    $pattern = (Element 106).GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern)
    $pattern.Toggle()
}
function Snapshot([string]$Name) {
    $element = [Windows.Automation.AutomationElement]::FromHandle($script:window)
    $elements = $element.FindAll([Windows.Automation.TreeScope]::Subtree, [Windows.Automation.Condition]::TrueCondition)
    $rows = foreach ($child in $elements) {
        $item = $child.Current
        [ordered]@{ name=$item.Name; id=$item.AutomationId; type=$item.ControlType.ProgrammaticName; enabled=$item.IsEnabled; offscreen=$item.IsOffscreen }
    }
    @($rows) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDir "$Name-ui.json") -Encoding UTF8
    $rect = New-Object WritWindow+Rect
    if ([WritWindow]::GetWindowRect($script:window, [ref]$rect)) {
        $bitmap = New-Object Drawing.Bitmap ($rect.Right-$rect.Left), ($rect.Bottom-$rect.Top)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $dc = $graphics.GetHdc()
        try { $captured = [WritWindow]::PrintWindow($script:window, $dc, 2) }
        finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
        if ($captured) { $bitmap.Save((Join-Path $OutputDir "$Name.png"), [Drawing.Imaging.ImageFormat]::Png) }
        $bitmap.Dispose()
    }
}
try {
    $app = Start-Process -FilePath $exe -PassThru
    Wait-For { [WritWindow]::FindWindow('WritDesktop.7DDDA5C1', 'Writ') -ne [IntPtr]::Zero } 'desktop window created'
    $script:window = [WritWindow]::FindWindow('WritDesktop.7DDDA5C1', 'Writ')
    Wait-For { (Text 204) -eq 'Watching hello.txt' } 'GUI observes provider readiness'
    Assert ((Text 203) -match 'only hello.txt.*64 KiB') 'public single-file scope visible'
    Assert (-not (Get-ItemProperty -LiteralPath $runKey -Name Writ -ErrorAction SilentlyContinue)) 'sign-in startup is opt-in'
    Assert ((Get-Content -LiteralPath $log -Raw) -match 'DESKTOP_TRAY_ADDED') 'Shell accepted notification-area icon'
    Assert ([WritWindow]::TrayIconExists($script:window)) 'Shell returns actual notification-icon rectangle'
    Snapshot 'activity-ready'
    $second = Start-Process -FilePath $exe -PassThru
    Assert ($second.WaitForExit(10000) -and $second.ExitCode -eq 0) 'second launch activates existing app'
    Assert (-not $app.HasExited) 'original app retains ownership'
    $bytes = [IO.File]::ReadAllBytes($hello)
    Assert ($bytes.Length -gt 0) 'GUI-owned provider hydrates public file'
    [IO.File]::WriteAllText($hello, "Saved through the desktop app.`r`n", (New-Object Text.UTF8Encoding $false))
    Wait-For { (Text 205) -eq 'Last save confirmed in the local backing store.' } 'GUI observes real confirmed save'
    # Drive the documented version-4 keyboard callback into the real window.
    # This covers callback and flyout controls, not human taskbar key injection.
    [void][WritWindow]::PostMessage($script:window, 0x8001, [IntPtr]::Zero, [IntPtr]0x00010401)
    Wait-For { [WritWindow]::FindWindow('WritFlyout.7DDDA5C1', 'Writ activity') -ne [IntPtr]::Zero } 'keyboard callback opens native activity flyout'
    $flyout = [WritWindow]::FindWindow('WritFlyout.7DDDA5C1', 'Writ activity')
    $flyPause = [Windows.Automation.AutomationElement]::FromHandle([WritWindow]::GetDlgItem($flyout, 103))
    $flyPause.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
    Wait-For { (Text 204) -eq 'Syncing paused' } 'Pause waits for actual provider exit'
    Assert ((Text 205) -match 'Unopened files need Writ running') 'pause explains hydration limitation'
    [IO.File]::WriteAllText($hello, "Edited while paused.`r`n", (New-Object Text.UTF8Encoding $false))
    Invoke-Control 103
    Wait-For { (Text 205) -eq 'Last save confirmed in the local backing store.' } 'Resume reconciles paused edit through provider'
    $info = & $cli inspect $root | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $info.inSync) 'resumed edit marked in sync by existing provider'
    # Exercise a real failed operation, then a recoverable edit. UI never
    # labels this as a completed save or discards the oversized local bytes.
    [IO.File]::WriteAllBytes($hello, (New-Object byte[] 65537))
    Wait-For { (Text 204) -eq 'Needs attention' } 'oversized file produces visible error'
    Assert ((Get-Item -LiteralPath $hello).Length -eq 65537) 'failed edit retained'
    Snapshot 'activity-error'
    [IO.File]::WriteAllText($hello, "Recovered valid edit.`r`n", (New-Object Text.UTF8Encoding $false))
    Wait-For { (Text 205) -eq 'Last save confirmed in the local backing store.' } 'valid edit clears observed error after commit'
    # Select the real native tab through UIA rather than an app test endpoint.
    $tabs = Element 110
    $settingsTab = $tabs.FindFirst([Windows.Automation.TreeScope]::Children,
        (New-Object Windows.Automation.PropertyCondition ([Windows.Automation.AutomationElement]::NameProperty), 'Settings'))
    Assert ($null -ne $settingsTab) 'settings tab exposed to accessibility'
    $settingsTab.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select()
    Wait-For { [WritWindow]::IsWindowVisible([WritWindow]::GetDlgItem($script:window, 106)) } 'settings panel displayed'
    Toggle-Startup
    Wait-For { $null -ne (Get-ItemProperty -LiteralPath $runKey -Name Writ -ErrorAction SilentlyContinue) } 'sign-in preference saved'
    $command = (Get-ItemProperty -LiteralPath $runKey -Name Writ).Writ
    Assert ($command -ceq ('"' + $exe + '" --background')) 'startup uses quoted exact installed executable'
    Toggle-Startup
    Wait-For { $null -eq (Get-ItemProperty -LiteralPath $runKey -Name Writ -ErrorAction SilentlyContinue) } 'sign-in preference removed'
    Snapshot 'settings'
    [void][WritWindow]::PostMessage($script:window, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
    Wait-For { -not [WritWindow]::IsWindowVisible($script:window) } 'window close hides to notification area'
    Assert (-not $app.HasExited) 'close-to-tray retains provider owner'
    $second = Start-Process -FilePath $exe -PassThru
    Assert ($second.WaitForExit(10000)) 'reopen command exits'
    Wait-For { [WritWindow]::IsWindowVisible($script:window) } 'second launch reopens hidden dashboard'
    Invoke-Control 105
    Assert ($app.WaitForExit(35000) -and $app.ExitCode -eq 0) 'Quit gracefully exits GUI and provider'
    $app = $null
    Assert ([IO.File]::ReadAllText($hello) -ceq "Recovered valid edit.`r`n") 'Quit retains hydrated user edit'
    Write-Host 'ALL WINDOWS DESKTOP CHECKS PASSED'
} catch {
    Write-Host $_.ScriptStackTrace
    if ($script:window -ne [IntPtr]::Zero -and -not ($app -and $app.HasExited)) {
        try { Snapshot 'failure' } catch { Write-Host "Failure capture unavailable: $_" }
    }
    throw
} finally {
    if ($app -and -not $app.HasExited) {
        $quitProcess = Start-Process -FilePath $exe -ArgumentList '--quit' -PassThru
        [void]$quitProcess.WaitForExit(35000)
        if (-not $app.WaitForExit(5000)) { $app.Kill(); $app.WaitForExit() }
    }
    if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log -Destination (Join-Path $OutputDir 'desktop-events.txt') }
    $clear = Start-Process -FilePath $exe -ArgumentList '--unregister-startup' -PassThru -Wait
    Stop-Transcript | Out-Null
}
