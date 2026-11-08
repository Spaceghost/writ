# Shared by the public-canary runner and its isolated process smoke test.
# Caller supplies $root, $results and $summary in the script scope.
function Run-Stage([string] $name, [string] $exe, [string] $argumentLine, [int] $timeoutSeconds) {
  Require-File $exe
  $stdout = Join-Path $results ($name + '.stdout')
  $stderr = Join-Path $results ($name + '.stderr')
  $status = Join-Path $results ($name + '.status')
  $command = Join-Path $results ($name + '.command')
  @("Executable: $exe", "Arguments: $argumentLine", "Timeout seconds: $timeoutSeconds", "Working directory: $root") |
    Set-Content -LiteralPath $command -Encoding UTF8
  # Mark intent before launch. A host crash after this point cannot leave a
  # launched stage falsely labelled NOT_RUN.
  Set-Content -LiteralPath $status -Value 'IN_PROGRESS; outcome and cleanup unknown' -Encoding UTF8

  $outFile = $null
  $errFile = $null
  $process = $null
  $outCopy = $null
  $errCopy = $null
  $started = $false
  $terminalRecorded = $false
  try {
    # Retain the Process returned by its own Start call. This avoids the
    # Start-Process/PassThru race where a very fast child yields a null ExitCode.
    $outFile = [IO.File]::Open($stdout,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    $errFile = [IO.File]::Open($stderr,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $exe
    $start.Arguments = $argumentLine
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Process.Start returned false' }
    $started = $true
    Set-Content -LiteralPath $status -Value 'PROCESS_STARTED; outcome and cleanup unknown' -Encoding UTF8
    # SMOKE_INJECT_AFTER_START
    # Copy raw bytes concurrently so neither pipe can deadlock and no output
    # is changed by text encoding conversion.
    $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($outFile)
    $errCopy = $process.StandardError.BaseStream.CopyToAsync($errFile)

    $finished = $process.WaitForExit($timeoutSeconds * 1000)
    if (-not $finished) {
      # Terminate only the retained process. Descendants and Windows resources
      # may remain; stop the sequence and do not claim cleanup on this path.
      try { $process.Kill(); [void]$process.WaitForExit(5000) } catch { }
    }
    $drained = $false
    $drainError = ''
    try {
      $tasks = [Threading.Tasks.Task[]]@($outCopy,$errCopy)
      $drained = [Threading.Tasks.Task]::WaitAll($tasks,5000)
    } catch { $drainError = $_.Exception.Message }
    if ($drained) {
      $outFile.Dispose(); $outFile = $null
      $errFile.Dispose(); $errFile = $null
    }
    # If a descendant still holds a pipe, never block indefinitely waiting for
    # stream completion. Process teardown closes remaining handles on exit.
    if (-not $finished) {
      Set-Content -LiteralPath $status -Value ("TIMEOUT; parent termination attempted; child/resource cleanup unverified; streams drained=$drained $drainError") -Encoding UTF8
      $terminalRecorded = $true
      Add-Content -LiteralPath $summary -Value "$name TIMEOUT; later stages NOT_RUN; cleanup unverified" -Encoding UTF8
      throw "$name timed out; stop and preserve the disposable VM for inspection"
    }
    if (-not $drained) {
      Set-Content -LiteralPath $status -Value ("OUTPUT_DRAIN_INCOMPLETE; child/resource cleanup unverified: $drainError") -Encoding UTF8
      $terminalRecorded = $true
      throw "$name output drain incomplete; later stages must not run"
    }
    # Check before casting: PowerShell would coerce a null to zero.
    $rawExit = $process.ExitCode
    # SMOKE_INJECT_EXITCODE
    if ($null -eq $rawExit) { throw 'Process exited without an observable exit code' }
    $code = [int]$rawExit
    $process.Dispose(); $process = $null
    Set-Content -LiteralPath $status -Value ("EXIT=" + $code) -Encoding ASCII
    $terminalRecorded = $true
    Add-Content -LiteralPath $summary -Value "$name EXIT=$code" -Encoding UTF8
    return ($code -eq 0)
  } catch {
    # Record the abnormal outcome before potentially failing cleanup. If the
    # status write itself fails, the operation errors and never reports PASS.
    if (-not $terminalRecorded) {
      $detail = $_.Exception.Message
      try { Set-Content -LiteralPath $status -Value ("ABNORMAL/UNKNOWN; cleanup unverified; started=$started; " + $detail) -Encoding UTF8 } catch { }
      try { Add-Content -LiteralPath $summary -Value "$name ABNORMAL/UNKNOWN; cleanup unverified" -Encoding UTF8 } catch { }
      if ($started -and $process) { try { $process.Kill() } catch { } }
    }
    # Do not block on disposing a stream with an unfinished async copy. If a
    # pipe remains open, script exit closes its handles without claiming cleanup.
    if ($outFile -and (-not $outCopy -or $outCopy.IsCompleted)) { try { $outFile.Dispose() } catch { } }
    if ($errFile -and (-not $errCopy -or $errCopy.IsCompleted)) { try { $errFile.Dispose() } catch { } }
    throw
  }
}
