[CmdletBinding()]
param(
    [string] $CredentialPath = (Join-Path $env:LOCALAPPDATA 'CopyQTranslation\azure-key.dpapi'),
    [string] $ConfigurationPath = (Join-Path $env:LOCALAPPDATA 'CopyQTranslation\translator.json'),
    [string] $Endpoint = 'https://api.cognitive.microsofttranslator.com',
    [string] $Region
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'CopyQ.Translation.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $repoRoot 'modules\CopyQ.Translation.psm1'
}
Import-Module $modulePath -Force

try {
    if ([string]::IsNullOrWhiteSpace($Region)) {
        $Region = Get-CopyQTranslatorRegion -ConfigurationPath $ConfigurationPath
    }
    try {
        $encodedSource = [Console]::In.ReadToEnd().Trim()
        $sourceBytes = [Convert]::FromBase64String($encodedSource)
        $sourceText = [Text.Encoding]::UTF8.GetString($sourceBytes)
    } catch {
        throw [InvalidOperationException]::new('TRANSLATE_FAILED')
    }
    $translated = Invoke-CopyQTranslator `
        -Text $sourceText `
        -CredentialPath $CredentialPath `
        -Endpoint $Endpoint `
        -Region $Region
    $translatedBytes = [Text.Encoding]::UTF8.GetBytes($translated)
    $encodedTranslation = [Convert]::ToBase64String($translatedBytes)
    [Console]::Out.Write($encodedTranslation)
    exit 0
} catch {
    $reason = $_.Exception.Message
    if ($reason -notin @('TRANSLATE_NOT_CONFIGURED', 'TRANSLATE_AUTH_FAILED', 'TRANSLATE_REGION_FAILED', 'TRANSLATE_RATE_LIMITED', 'TRANSLATE_FAILED', 'TRANSLATE_EMPTY')) {
        $reason = 'TRANSLATE_FAILED'
    }
    [Console]::Error.Write($reason)
    exit 1
}
