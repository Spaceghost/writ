# Fixed no-data sequence. No argument selects an image, process, handle or data.
$ErrorActionPreference = 'Stop'
if ($args.Count -ne 0) { throw 'No arguments are accepted.' }
$logs = Join-Path $env:RUNNER_TEMP 'windows-combined-ad-logs'
$build = Join-Path $env:RUNNER_TEMP 'windows-combined-ad-build\Release'
$expectedChildHash = (Get-FileHash (Join-Path $build 'writfs-init-child.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
$cases = @(
  @{ Name = 'ordinary-before'; Exe = 'writfs-pss-init-control.exe'; Timeout = 30000; Hashes = 1 },
  @{ Name = 'combined-adda'; Exe = 'writfs-combined-ad-observer.exe'; Timeout = 120000; Hashes = 4 },
  @{ Name = 'ordinary-after'; Exe = 'writfs-pss-init-control.exe'; Timeout = 30000; Hashes = 1 }
)
foreach ($case in $cases) {
  $statusLog = Join-Path $logs ($case.Name + '-supervision.txt')
  try {
    $process = Start-Process -FilePath (Join-Path $build $case.Exe) -PassThru -NoNewWindow `
      -RedirectStandardOutput (Join-Path $logs ($case.Name + '-stdout.txt')) `
      -RedirectStandardError (Join-Path $logs ($case.Name + '-stderr.txt'))
    if (-not $process.WaitForExit($case.Timeout)) {
      'timeout=1 observer_termination=attempting cleanup=unverified' | Out-File $statusLog -Encoding utf8
      try {
        $process.Kill()
        'observer_termination=requested' | Add-Content $statusLog -Encoding utf8
      } catch {
        "observer_termination=failed detail=$_" | Add-Content $statusLog -Encoding utf8
      }
      $retired = $process.WaitForExit(5000)
      "observer_exit_observed=$retired child_cleanup=unverified vm_teardown=fallback" | Add-Content $statusLog -Encoding utf8
      throw 'Observation timed out; scoped cleanup is unverified.'
    }
    $process.Refresh()
    "timeout=0 observer_exit=$($process.ExitCode)" | Out-File $statusLog -Encoding utf8
    if ($process.ExitCode -ne 0) { throw 'Observation or cleanup incomplete.' }
    $stdout = Get-Content (Join-Path $logs ($case.Name + '-stdout.txt')) -Raw
    $hashes = [regex]::Matches($stdout, 'image_sha256=([0-9a-f]{64})')
    if ($hashes.Count -ne $case.Hashes -or @($hashes | Where-Object { $_.Groups[1].Value -ne $expectedChildHash }).Count -ne 0) {
      throw 'Held child image hash does not match the built fixed child.'
    }
    'child_image_hash_matches_build=1' | Add-Content $statusLog -Encoding utf8
  } catch {
    "Sequence stopped; no further case: $_" | Add-Content $statusLog -Encoding utf8
    throw
  }
}
'Ordinary controls and one exploratory ADDA sequence completed; no confinement credit or causal claim.' |
  Out-File (Join-Path $logs 'sequence.txt') -Encoding utf8
