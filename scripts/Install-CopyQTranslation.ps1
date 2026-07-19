[CmdletBinding()]
param(
    [string] $DestinationRoot = (Join-Path $env:LOCALAPPDATA 'CopyQCommandSuite\translation'),
    [string] $CredentialPath = (Join-Path $env:LOCALAPPDATA 'CopyQTranslation\azure-key.dpapi'),
    [string] $ConfigurationPath = (Join-Path $env:LOCALAPPDATA 'CopyQTranslation\translator.json'),
    [string] $Region,
    [switch] $SkipConfiguration
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$destination = [IO.Path]::GetFullPath($DestinationRoot)
if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
    New-Item -ItemType Directory -Path $destination | Out-Null
}

$files = @(
    @{ Source = Join-Path $repoRoot 'modules\CopyQ.Translation.psm1'; Name = 'CopyQ.Translation.psm1' },
    @{ Source = Join-Path $PSScriptRoot 'Invoke-CopyQAzureTranslation.ps1'; Name = 'Invoke-CopyQAzureTranslation.ps1' },
    @{ Source = Join-Path $PSScriptRoot 'Set-CopyQAzureTranslator.ps1'; Name = 'Set-CopyQAzureTranslator.ps1' }
)
foreach ($file in $files) {
    Copy-Item -LiteralPath $file.Source -Destination (Join-Path $destination $file.Name) -Force
}

if (-not $SkipConfiguration) {
    $setScript = Join-Path $destination 'Set-CopyQAzureTranslator.ps1'
    & $setScript -CredentialPath $CredentialPath -ConfigurationPath $ConfigurationPath -Region $Region | Out-Null
}

Write-Output 'COPYQ_TRANSLATION_INSTALLED'
