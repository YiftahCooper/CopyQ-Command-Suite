[CmdletBinding()]
param(
    [string] $CredentialPath = (Join-Path $env:LOCALAPPDATA 'CopyQTranslation\azure-key.dpapi'),
    [string] $ConfigurationPath = (Join-Path $env:LOCALAPPDATA 'CopyQTranslation\translator.json'),
    [string] $Region
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CopyQ.Translation.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $repoRoot 'modules\CopyQ.Translation.psm1'
}
Import-Module $modulePath -Force

$secureKey = Read-Host 'Paste the Azure Translator key' -AsSecureString
if ([string]::IsNullOrWhiteSpace($Region)) {
    $Region = Read-Host 'Azure Translator region (for example germanywestcentral)'
}
Set-CopyQTranslatorCredential -SecureKey $secureKey -CredentialPath $CredentialPath | Out-Null
Set-CopyQTranslatorRegion -Region $Region -ConfigurationPath $ConfigurationPath | Out-Null
Write-Output 'AZURE_TRANSLATOR_CONFIGURED'
