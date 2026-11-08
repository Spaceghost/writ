# Isolated non-native smoke of the exact process wrapper used by run-canary.ps1.
# Uses only fixed Windows commands in the disposable VM; no Writ/native probe.
$ErrorActionPreference = 'Stop'
$root = 'C:\writ-stage'
$results = 'C:\writ-stage\process-smoke-01'
$summary = Join-Path $results 'summary.txt'
if (Test-Path -LiteralPath $results) { throw 'Smoke result directory already exists.' }
New-Item -ItemType Directory -Path $results -ErrorAction Stop | Out-Null
Set-Content -LiteralPath $summary -Value 'Isolated PS5 process-wrapper smoke.' -Encoding UTF8
function Require-File([string] $path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
}
. 'C:\writ-stage\process-wrapper-smoke.ps1'
function Require-Status([string] $name, [string] $expected) {
  $status = (Get-Content -LiteralPath (Join-Path $results ($name + '.status')) -Raw).Trim()
  if ($status -ne $expected) { throw "$name status was: $status" }
}
try {
  $cmd = 'C:\Windows\System32\cmd.exe'
  $ps = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
  Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\writ-stage\process-wrapper-smoke.ps1',
    'C:\writ-stage\process-smoke.ps1' | Format-List |
      Out-File -LiteralPath (Join-Path $results 'script-hashes.txt') -Encoding UTF8
  for ($i = 0; $i -lt 20; $i++) {
    $zero = 'fast-zero-' + $i
    $seven = 'fast-seven-' + $i
    if (-not (Run-Stage $zero $cmd '/d /c exit 0' 10)) { throw "$zero should pass" }
    Require-Status $zero 'EXIT=0'
    if (Run-Stage $seven $cmd '/d /c exit 7' 10) { throw "$seven should fail" }
    Require-Status $seven 'EXIT=7'
  }
  Add-Content -LiteralPath $summary -Value 'PASS 20 fast zero and 20 fast nonzero processes retain exact exit status' -Encoding UTF8
  if (-not (Run-Stage 'streams' $cmd '/d /c echo(OUTMARKER&1>&2 echo(ERRMARKER&exit 0' 10)) { throw 'stream command failed' }
  Require-Status 'streams' 'EXIT=0'
  $stdout = [IO.File]::ReadAllBytes((Join-Path $results 'streams.stdout'))
  $stderr = [IO.File]::ReadAllBytes((Join-Path $results 'streams.stderr'))
  if ([Convert]::ToBase64String($stdout) -ne [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("OUTMARKER`r`n"))) { throw 'stdout bytes differ' }
  if ([Convert]::ToBase64String($stderr) -ne [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("ERRMARKER`r`n"))) { throw 'stderr bytes differ' }
  Add-Content -LiteralPath $summary -Value 'PASS stdout/stderr captured as separate exact raw byte streams' -Encoding UTF8
  $caught = $false
  try { [void](Run-Stage 'timeout' $ps '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 20"' 2) }
  catch { $caught = $true }
  if (-not $caught) { throw 'timeout was not reported' }
  $timeoutStatus = (Get-Content -LiteralPath (Join-Path $results 'timeout.status') -Raw).Trim()
  if (-not $timeoutStatus.StartsWith('TIMEOUT;')) { throw "Unexpected timeout status: $timeoutStatus" }
  Add-Content -LiteralPath $summary -Value 'PASS timeout reported with cleanup unverified' -Encoding UTF8

  # The original wrapper above is used unmodified for fast exits, raw streams
  # and timeout. The following two smoke-only copies inject exceptions at
  # inert comment markers to verify fail-closed status, never the production path.
  $source = [IO.File]::ReadAllText('C:\writ-stage\process-wrapper-smoke.ps1')
  if (-not $source.Contains('# SMOKE_INJECT_AFTER_START') -or -not $source.Contains('# SMOKE_INJECT_EXITCODE')) { throw 'Missing smoke injection markers' }
  $injectedStart = Join-Path $results 'injected-after-start.ps1'
  [IO.File]::WriteAllText($injectedStart,$source.Replace('# SMOKE_INJECT_AFTER_START',"throw 'injected post-start failure'"))
  . $injectedStart
  $caught = $false
  try { [void](Run-Stage 'injected-poststart' $ps '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 20"' 10) }
  catch { $caught = $true }
  if (-not $caught) { throw 'post-start injection did not fail' }
  $injectedStatus = (Get-Content -LiteralPath (Join-Path $results 'injected-poststart.status') -Raw).Trim()
  if (-not $injectedStatus.StartsWith('ABNORMAL/UNKNOWN; cleanup unverified; started=True;')) { throw "Unexpected post-start status: $injectedStatus" }
  Add-Content -LiteralPath $summary -Value 'PASS post-start exception recorded as abnormal with cleanup unverified' -Encoding UTF8

  $injectedNull = Join-Path $results 'injected-null-exit.ps1'
  [IO.File]::WriteAllText($injectedNull,$source.Replace('# SMOKE_INJECT_EXITCODE','$rawExit = $null'))
  . $injectedNull
  $caught = $false
  try { [void](Run-Stage 'injected-null-exit' $cmd '/d /c exit 0' 10) }
  catch { $caught = $true }
  if (-not $caught) { throw 'null-exit injection did not fail' }
  $nullStatus = (Get-Content -LiteralPath (Join-Path $results 'injected-null-exit.status') -Raw).Trim()
  if (-not $nullStatus.StartsWith('ABNORMAL/UNKNOWN; cleanup unverified; started=True;')) { throw "Unexpected null-exit status: $nullStatus" }
  Add-Content -LiteralPath $summary -Value 'PASS missing exit status is abnormal and never coerced to zero' -Encoding UTF8
  Get-FileHash -Algorithm SHA256 -LiteralPath $injectedStart,$injectedNull | Format-List |
    Out-File -LiteralPath (Join-Path $results 'injected-wrapper-hashes.txt') -Encoding UTF8
  Add-Content -LiteralPath $summary -Value 'ALL ISOLATED PROCESS-WRAPPER SMOKE CHECKS PASSED' -Encoding UTF8
  Write-Output 'ALL ISOLATED PROCESS-WRAPPER SMOKE CHECKS PASSED'
  exit 0
} catch {
  $_ | Out-String | Set-Content -LiteralPath (Join-Path $results 'smoke-error.txt') -Encoding UTF8
  Write-Error $_
  exit 1
}
