# Independent benign inherited-pipe smoke. Same unmodified process wrapper.
$ErrorActionPreference = 'Stop'
$root = 'C:\writ-stage'
$results = 'C:\writ-stage\process-smoke-04'
$summary = Join-Path $results 'summary.txt'
if (Test-Path -LiteralPath $results) { throw 'Smoke result directory already exists.' }
New-Item -ItemType Directory -Path $results -ErrorAction Stop | Out-Null
Set-Content -LiteralPath $summary -Value 'Owned CMD descendant inherited-pipe smoke.' -Encoding UTF8
function Require-File([string] $path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
}
. 'C:\writ-stage\process-wrapper-smoke.ps1'
try {
  $cmd = 'C:\Windows\System32\cmd.exe'
  $clock = [Diagnostics.Stopwatch]::StartNew()
  $caught = $false
  try { [void](Run-Stage 'inherited-pipes' $cmd '/d /c C:\writ-stage\pipe-parent.cmd' 10) }
  catch { $caught = $true }
  $clock.Stop()
  Set-Content -LiteralPath (Join-Path $results 'return-ms.txt') -Value $clock.ElapsedMilliseconds -Encoding ASCII
  Start-Sleep -Seconds 15
  foreach ($name in @('child-started.txt','child-late.txt','child-write-attempted.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $results $name))) { throw "Missing child positive control: $name" }
  }
  $status = (Get-Content -LiteralPath (Join-Path $results 'inherited-pipes.status') -Raw).Trim()
  if (-not $caught -or -not $status.StartsWith('OUTPUT_DRAIN_INCOMPLETE;')) {
    throw "Expected incomplete drain after child startup and late write; observed: $status"
  }
  Add-Content -LiteralPath $summary -Value 'PASS live descendant triggered bounded output-drain incomplete' -Encoding UTF8
  Write-Output 'ALL ISOLATED INHERITED-PIPE CHECKS PASSED'
  exit 0
} catch {
  $_ | Out-String | Set-Content -LiteralPath (Join-Path $results 'smoke-error.txt') -Encoding UTF8
  Write-Error $_
  exit 1
}
