# Fixed no-data sequence. No argument selects an image, process, handle or data.
$ErrorActionPreference = 'Stop'
if ($args.Count -ne 0) { throw 'No arguments are accepted.' }
$logs = Join-Path $env:RUNNER_TEMP 'windows-pss-init-logs'
$build = Join-Path $env:RUNNER_TEMP 'windows-pss-init-build\Release'
$expectedChildHash = (Get-FileHash (Join-Path $build 'writfs-init-child.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
$cases = @(
  @{ Name = 'ordinary-before'; Exe = 'writfs-pss-init-control.exe' },
  @{ Name = 'lpac-first'; Exe = 'writfs-pss-init-observer.exe' },
  @{ Name = 'lpac-second'; Exe = 'writfs-pss-init-observer.exe' },
  @{ Name = 'ordinary-after'; Exe = 'writfs-pss-init-control.exe' }
)
foreach ($case in $cases) {
  $statusLog = Join-Path $logs ($case.Name + '-supervision.txt')
  try {
    $process = Start-Process -FilePath (Join-Path $build $case.Exe) -PassThru -NoNewWindow `
      -RedirectStandardOutput (Join-Path $logs ($case.Name + '-stdout.txt')) `
      -RedirectStandardError (Join-Path $logs ($case.Name + '-stderr.txt'))
    if (-not $process.WaitForExit(30000)) {
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
    if ($hashes.Count -ne 1 -or $hashes[0].Groups[1].Value -ne $expectedChildHash) {
      throw 'Held child image hash does not match the built fixed child.'
    }
    'child_image_hash_matches_build=1' | Add-Content $statusLog -Encoding utf8
  } catch {
    "Sequence stopped; no further case: $_" | Add-Content $statusLog -Encoding utf8
    throw
  }
}
'All four separate no-data cases completed; no confinement credit.' |
  Out-File (Join-Path $logs 'sequence.txt') -Encoding utf8
