[CmdletBinding()]
param(
    [string]$ReportPath = '',
    [string]$LuauPath = '',
    [string]$CompilerPath = '',
    [string]$Python = 'python',
    [string[]]$AdditionalSuite = @(),
    [switch]$VerifyFailClosed,
    [ValidateRange(5, 600)][int]$CommandTimeoutSeconds = 120
)

# Offline validation only. Does not install, launch Studio, publish, or modify game assets.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ReportPath) { $ReportPath = Join-Path $repoRoot 'docs/qa/latest-checks.json' }
if (-not [IO.Path]::IsPathRooted($ReportPath)) { $ReportPath = Join-Path $repoRoot $ReportPath }
if (-not $LuauPath) { $LuauPath = Join-Path $repoRoot '.tools/luau/luau.exe' }
if (-not $CompilerPath) { $CompilerPath = Join-Path $repoRoot '.tools/luau/luau-compile.exe' }
$shellPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$started = [DateTime]::UtcNow
$checks = [Collections.Generic.List[object]]::new()

function ConvertTo-NativeArgument([string]$Value) {
    # Windows argv quoting for Windows PowerShell 5.1; no shell interpolation.
    if ($Value -ne '' -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-Captured([string]$Executable, [string[]]$Arguments) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $Executable
    $process.StartInfo.WorkingDirectory = $repoRoot
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    # ArgumentList is unavailable on .NET Framework / Windows PowerShell 5.1.
    if ($process.StartInfo.PSObject.Properties.Name -contains 'ArgumentList') {
        foreach ($argument in $Arguments) { $process.StartInfo.ArgumentList.Add($argument) }
    } else {
        $process.StartInfo.Arguments = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($CommandTimeoutSeconds * 1000)
        if ($timedOut) { $process.Kill(); $process.WaitForExit() }
        $result = [pscustomobject]@{
            exit_code = $(if ($timedOut) { 124 } else { $process.ExitCode })
            stdout = $stdout.GetAwaiter().GetResult()
            stderr = $stderr.GetAwaiter().GetResult()
            timed_out = $timedOut
            seconds = [math]::Round($watch.Elapsed.TotalSeconds, 3)
        }
    } catch {
        $result = [pscustomobject]@{exit_code = 127; stdout = ''; stderr = $_.Exception.Message;
            timed_out = $false; seconds = [math]::Round($watch.Elapsed.TotalSeconds, 3)}
    } finally {
        $watch.Stop()
        $process.Dispose()
    }
    return $result
}

function Add-Check([string]$Id, [string]$Executable, [string[]]$Arguments,
    [int]$ExpectedExitCode = 0, [switch]$AudioSummary) {
    $result = Invoke-Captured $Executable $Arguments
    $output = ($result.stdout.TrimEnd() + "`n" + $result.stderr.TrimEnd()).Trim()
    $summary = $null
    if ($AudioSummary -and $result.exit_code -eq 0) {
        try {
            $marker = $result.stdout.LastIndexOf('PASS:')
            if ($marker -lt 0) { throw 'Audio verifier did not emit its completion marker' }
            $manifest = $result.stdout.Substring(0, $marker) | ConvertFrom-Json
            $summary = [ordered]@{files = @($manifest.files).Count; total_bytes = $manifest.total_bytes;
                manifest = 'assets/audio/manifest.json'}
            $output = $result.stdout.Substring($marker).Trim()
        } catch {
            $result.exit_code = 1
            $output = 'Audio completion validation failed: ' + $_.Exception.Message
        }
    }
    $fullLength = $output.Length
    if ($fullLength -gt 8000) { $output = $output.Substring(0, 3500) + "`n[output truncated]`n" + $output.Substring($fullLength - 3500) }
    $check = [pscustomobject][ordered]@{
        id = $Id; executable = $Executable; arguments = @($Arguments)
        exit_code = $result.exit_code; expected_exit_code = $ExpectedExitCode
        passed = ($result.exit_code -eq $ExpectedExitCode); timed_out = $result.timed_out
        seconds = $result.seconds; output = $output
        output_characters = $fullLength; output_truncated = ($fullLength -gt 8000)
    }
    if ($null -ne $summary) { $check | Add-Member -NotePropertyName summary -NotePropertyValue $summary }
    $checks.Add($check)
    Write-Host (('{0} {1} (exit {2})' -f $(if ($check.passed) { 'PASS' } else { 'FAIL' }), $Id, $result.exit_code))
    return $check
}

$revision = Invoke-Captured 'git' @('rev-parse', 'HEAD')
$gitStatus = Invoke-Captured 'git' @('status', '--porcelain=v1', '--untracked-files=normal')
$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'game') -Filter '*.luau' -Recurse -File | Sort-Object FullName)
$suites = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tests') -Filter '*.spec.luau' -File | Sort-Object FullName)
$excludedSuites = @([ordered]@{path = 'tests/CascadeState.spec.luau';
    reason = 'Archived Cascade engine-only suite requires game.ReplicatedStorage; outside Spark offline scope. Not passed by this runner.'})
$hashes = [ordered]@{}
foreach ($file in @($sourceFiles) + @($suites)) {
    $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
    $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
foreach ($relative in @('tools/run_checks.ps1', 'tests/SparkWorldSmoke.ps1', 'tools/generate_audio.py', 'assets/audio/manifest.json')) {
    $hashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $repoRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
}

if ($sourceFiles.Count -eq 0 -or $suites.Count -eq 0) { throw 'No production sources or test suites discovered; refusing an empty pass' }
foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
    [void](Add-Check ('compile:' + $relative) $CompilerPath @('--null', $relative))
}
foreach ($file in $suites) {
    $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
    if ($relative -eq 'tests/CascadeState.spec.luau') { continue }
    [void](Add-Check ('suite:' + $relative) $LuauPath @($relative))
}
foreach ($path in $AdditionalSuite) {
    [void](Add-Check ('additional-suite:' + $path) $LuauPath @($path))
}
[void](Add-Check 'world-constructor-mock' $shellPath @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    (Join-Path $repoRoot 'tests/SparkWorldSmoke.ps1'), '-Luau', $LuauPath))
[void](Add-Check 'audio-format-and-manifest' $Python @('tools/generate_audio.py', '--verify') -AudioSummary)

if ($VerifyFailClosed) {
    # A disposable, intentionally failing extra suite proves the runner propagates failure.
    # No production/test source is altered. Child runs omit this switch to avoid recursion.
    $probeRoot = Join-Path ([IO.Path]::GetTempPath()) ('spark check failure ' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($probeRoot)
    $probeSuite = Join-Path $probeRoot 'intentional-failure.luau'
    $probeReport = Join-Path $probeRoot 'report.json'
    try {
        [IO.File]::WriteAllText($probeSuite, 'error("intentional runner fail-closed validation")', [Text.UTF8Encoding]::new($false))
        $probe = Add-Check 'runner-fail-closed-probe' $shellPath @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            $PSCommandPath, '-ReportPath', $probeReport, '-LuauPath', $LuauPath, '-CompilerPath', $CompilerPath,
            '-Python', $Python, '-AdditionalSuite', $probeSuite) -ExpectedExitCode 1
        try {
            $child = Get-Content -LiteralPath $probeReport -Raw | ConvertFrom-Json
            $failedSuite = @($child.checks | Where-Object { $_.id -eq ('additional-suite:' + $probeSuite) -and $_.exit_code -ne 0 })
            if ($child.status -ne 'failed' -or $child.exit_code -ne 1 -or $failedSuite.Count -ne 1 -or $child.failed_count -ne 1) {
                throw 'Child did not record the intentionally failed suite and overall failure'
            }
            $probe | Add-Member -NotePropertyName validated_child_failure -NotePropertyValue $true
            $probe.output = 'Expected child exit 1; JSON status=failed; intentional additional suite exit=' + $failedSuite[0].exit_code
            $probe.output_characters = $probe.output.Length
            $probe.output_truncated = $false
        } catch {
            $probe.passed = $false
            $probe.output += "`nFailure evidence invalid: " + $_.Exception.Message
        }
    } finally {
        # Only individually named files under the freshly created disposable directory.
        foreach ($path in @($probeSuite, $probeReport)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
        Remove-Item -LiteralPath $probeRoot
    }
}

$failed = @($checks | Where-Object { -not $_.passed })
$changedSources = @($hashes.Keys | Where-Object {
    $path = Join-Path $repoRoot $_
    -not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashes[$_]
})
$exitCode = if ($failed.Count -gt 0 -or $changedSources.Count -gt 0 -or $revision.exit_code -ne 0 -or $gitStatus.exit_code -ne 0) { 1 } else { 0 }
$toolHashes = [ordered]@{}
foreach ($path in @($LuauPath, $CompilerPath)) {
    if (Test-Path -LiteralPath $path) { $toolHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$pythonVersion = Invoke-Captured $Python @('--version')
$report = [ordered]@{
    schema_version = 1; evidence_class = 'offline compilation, pure modules, mocked world constructor and audio file analysis'
    not_tested = @('Studio gameplay', 'real multiplayer', 'real DataStore', 'rendering', 'audible playback', 'device performance')
    started_utc = $started.ToString('o'); completed_utc = [DateTime]::UtcNow.ToString('o')
    git_revision = $revision.stdout.Trim(); dirty = [bool]($gitStatus.stdout.Trim()); git_status = @($gitStatus.stdout.TrimEnd() -split "`r?`n" | Where-Object { $_ })
    environment = [ordered]@{os = [Environment]::OSVersion.VersionString; powershell = $PSVersionTable.PSVersion.ToString(); cwd = $repoRoot;
        python_version = ($pythonVersion.stdout + $pythonVersion.stderr).Trim(); executable_sha256 = $toolHashes}
    status = $(if ($exitCode -eq 0) { 'passed' } else { 'failed' }); exit_code = $exitCode
    check_count = $checks.Count; failed_count = $failed.Count; excluded_suites = $excludedSuites
    sources_changed_during_run = $changedSources; source_sha256 = $hashes; checks = @($checks.ToArray())
}
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $ReportPath))
[IO.File]::WriteAllText($ReportPath, (($report | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Host ('Report: ' + $ReportPath)
Write-Host ('Offline checks: ' + $report.status + '; ' + $failed.Count + ' failed of ' + $checks.Count)
exit $exitCode
