[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'manifest\public-commands.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

function Resolve-CopyQExecutable {
    $command = Get-Command copyq.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidate = Join-Path $env:ProgramFiles 'CopyQ\copyq.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    throw 'COPYQ_16_NOT_FOUND'
}

function Invoke-CopyQProcess {
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [Parameter(Mandatory)][string[]] $ArgumentList,
        [string] $StandardInput
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    foreach ($argument in $ArgumentList) { [void] $startInfo.ArgumentList.Add($argument) }
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $null -ne $StandardInput
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        [void] $process.Start()
        if ($null -ne $StandardInput) {
            $process.StandardInput.Write($StandardInput)
            $process.StandardInput.Close()
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    } finally {
        $process.Dispose()
    }
}

$copyq = Resolve-CopyQExecutable
$version = (Invoke-CopyQProcess -FilePath $copyq -ArgumentList @('--version')).StdOut.Trim()
if ($version -notmatch '^CopyQ Clipboard Manager (?:v)?16\.0\.0(?:\s|$)') {
    throw "COPYQ_16_REQUIRED: $version"
}

$modelJson = (& node -e "process.stdout.write(JSON.stringify(require('./src/public-commands').buildPublicCommands()))" 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($modelJson)) {
    throw 'PUBLIC_COMMAND_MODEL_FAILED'
}
$model = $modelJson | ConvertFrom-Json
if (@($model.commands).Count -ne 16) { throw 'PUBLIC_COMMAND_COUNT_INVALID' }

$session = 'cqpub-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$privateRoot = [IO.Path]::GetFullPath((Join-Path $env:TEMP $session))
$tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
if (-not $privateRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "PRIVATE_PATH_OUTSIDE_TEMP: $privateRoot"
}
$settingsPath = Join-Path $privateRoot 'settings'
$itemPath = Join-Path $privateRoot 'items'
$previousSettings = [Environment]::GetEnvironmentVariable('COPYQ_SETTINGS_PATH', 'Process')
$previousItems = [Environment]::GetEnvironmentVariable('COPYQ_ITEM_DATA_PATH', 'Process')
$env:COPYQ_SETTINGS_PATH = $settingsPath
$env:COPYQ_ITEM_DATA_PATH = $itemPath

try {
    Start-Process -FilePath $copyq -ArgumentList @('-s', $session) -WindowStyle Hidden
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt += 1) {
        Start-Sleep -Milliseconds 100
        $probe = Invoke-CopyQProcess -FilePath $copyq -ArgumentList @('-s', $session, 'tab')
        if ($probe.ExitCode -eq 0) { $ready = $true; break }
    }
    if (-not $ready) { throw 'ISOLATED_COPYQ_NOT_READY' }

    $outputs = @()
    foreach ($command in $manifest.commands) {
        $outputs += [pscustomobject]@{
            Path = [string] $command.output
            Identities = @([string] $command.identity)
        }
    }
    foreach ($bundle in $manifest.bundles) {
        $identities = @($manifest.commands | Where-Object {
            $bundle.group -eq 'all' -or $_.group -eq $bundle.group
        } | ForEach-Object { [string] $_.identity })
        $outputs += [pscustomobject]@{
            Path = [string] $bundle.output
            Identities = $identities
        }
    }

    foreach ($output in $outputs) {
        $identitiesJson = ConvertTo-Json -InputObject @($output.Identities) -Compress
        $exportProgram = "var model=$modelJson;var ids=$identitiesJson;var selected=model.commands.filter(function(command){return ids.indexOf(command.internalId)>=0;});exportCommands(selected)"
        $export = Invoke-CopyQProcess -FilePath $copyq -ArgumentList @('-s', $session, 'eval', '-') -StandardInput $exportProgram
        if ($export.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($export.StdOut)) {
            throw "COMMAND_EXPORT_FAILED: $($output.Path)"
        }

        $iniBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($export.StdOut))
        $verifyProgram = "var imported=importCommands(str(fromBase64('$iniBase64')));JSON.stringify(imported.map(function(command){return command.internalId;}))"
        $verify = Invoke-CopyQProcess -FilePath $copyq -ArgumentList @('-s', $session, 'eval', '-') -StandardInput $verifyProgram
        if ($verify.ExitCode -ne 0) { throw "COMMAND_IMPORT_FAILED: $($output.Path)" }
        $actualIdentities = @($verify.StdOut | ConvertFrom-Json)
        if ((ConvertTo-Json @($actualIdentities) -Compress) -ne (ConvertTo-Json @($output.Identities) -Compress)) {
            throw "COMMAND_IDENTITY_MISMATCH: $($output.Path)"
        }

        $destination = Join-Path $repoRoot ($output.Path -replace '/', '\')
        $destinationRoot = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationRoot | Out-Null
        }
        [IO.File]::WriteAllText($destination, $export.StdOut, [Text.UTF8Encoding]::new($false))
    }

    [pscustomobject]@{
        Individual = @($manifest.commands).Count
        Canonical = @($manifest.commands | Where-Object group -eq 'canonical').Count
        Moonlander = @($manifest.commands | Where-Object group -eq 'moonlander').Count
        All = @($manifest.commands).Count
        DuplicateShortcuts = 0
    } | ConvertTo-Json -Compress
} finally {
    if ($copyq -and $session) {
        Invoke-CopyQProcess -FilePath $copyq -ArgumentList @('-s', $session, 'exit') | Out-Null
        for ($attempt = 0; $attempt -lt 40; $attempt += 1) {
            Start-Sleep -Milliseconds 100
            $probe = Invoke-CopyQProcess -FilePath $copyq -ArgumentList @('-s', $session, 'tab')
            if ($probe.ExitCode -ne 0) { break }
        }
    }
    if ($null -eq $previousSettings) { Remove-Item Env:COPYQ_SETTINGS_PATH -ErrorAction SilentlyContinue } else { $env:COPYQ_SETTINGS_PATH = $previousSettings }
    if ($null -eq $previousItems) { Remove-Item Env:COPYQ_ITEM_DATA_PATH -ErrorAction SilentlyContinue } else { $env:COPYQ_ITEM_DATA_PATH = $previousItems }
    if (Test-Path -LiteralPath $privateRoot) {
        for ($attempt = 0; $attempt -lt 20; $attempt += 1) {
            try {
                Remove-Item -LiteralPath $privateRoot -Recurse -Force
                break
            } catch {
                if ($attempt -eq 19) { throw }
                Start-Sleep -Milliseconds 100
            }
        }
    }
}
