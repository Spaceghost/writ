#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Start', 'Stop', 'Remove')][string]$Action = 'Start',
    [Parameter(Mandatory)][string]$BuildDir,
    [string]$Root = (Join-Path $env:USERPROFILE 'Writ'),
    [string]$Store = (Join-Path $env:LOCALAPPDATA 'WritDemo\store'),
    [string]$Node = (Get-Command node -ErrorAction Stop).Source
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This demo requires native Windows and NTFS.' }
$exe = Join-Path $BuildDir 'Release\writ-cloud.exe'
$module = Join-Path $BuildDir 'public-sync.mjs'
$bridge = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\runtime\node-policy.mjs'))
switch ($Action) {
    'Start' {
        if (-not (Test-Path -LiteralPath $module)) { throw "Generate PublicSync.bend as $module first; see README.md." }
        [IO.Directory]::CreateDirectory((Split-Path $Store)) | Out-Null
        & $exe seed $Store
        if ($LASTEXITCODE) { throw 'Seeding failed.' }
        & $exe serve $Root $Store $Node $bridge $module
    }
    'Stop' { & $exe stop $Root }
    'Remove' { & $exe remove $Root $Store }
}
if ($LASTEXITCODE) { throw "$Action failed ($LASTEXITCODE). Files and recovery data were retained." }
