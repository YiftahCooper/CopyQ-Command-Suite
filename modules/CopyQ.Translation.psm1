Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-CopyQTranslatorCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Security.SecureString] $SecureKey,

        [Parameter(Mandatory)]
        [string] $CredentialPath
    )

    $fullPath = [IO.Path]::GetFullPath($CredentialPath)
    $directory = Split-Path -Parent $fullPath
    if ([string]::IsNullOrWhiteSpace($directory)) {
        throw [InvalidOperationException]::new('TRANSLATE_NOT_CONFIGURED')
    }
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $ciphertext = ConvertFrom-SecureString -SecureString $SecureKey
    if ([string]::IsNullOrWhiteSpace($ciphertext)) {
        throw [InvalidOperationException]::new('TRANSLATE_NOT_CONFIGURED')
    }
    [IO.File]::WriteAllText($fullPath, $ciphertext, [Text.UTF8Encoding]::new($false))
    return Get-Item -LiteralPath $fullPath
}

function Get-CopyQTranslatorKey {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $CredentialPath)

    if (-not (Test-Path -LiteralPath $CredentialPath -PathType Leaf)) {
        throw [InvalidOperationException]::new('TRANSLATE_NOT_CONFIGURED')
    }
    try {
        $ciphertext = Get-Content -LiteralPath $CredentialPath -Raw
        $secureKey = ConvertTo-SecureString -String $ciphertext
        $credential = [Management.Automation.PSCredential]::new('copyq-translator', $secureKey)
        $plainKey = $credential.GetNetworkCredential().Password
        if ([string]::IsNullOrWhiteSpace($plainKey)) {
            throw 'empty credential'
        }
        return $plainKey
    } catch {
        throw [InvalidOperationException]::new('TRANSLATE_NOT_CONFIGURED')
    }
}

function Set-CopyQTranslatorRegion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Region,
        [Parameter(Mandatory)][string] $ConfigurationPath
    )

    $normalized = $Region.Trim().ToLowerInvariant()
    if ($normalized -notmatch '^[a-z0-9]+$') {
        throw [InvalidOperationException]::new('TRANSLATE_REGION_FAILED')
    }
    $fullPath = [IO.Path]::GetFullPath($ConfigurationPath)
    $directory = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $json = ConvertTo-Json -InputObject ([ordered]@{ region = $normalized }) -Compress
    [IO.File]::WriteAllText($fullPath, $json, [Text.UTF8Encoding]::new($false))
    return Get-Item -LiteralPath $fullPath
}

function Get-CopyQTranslatorRegion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $ConfigurationPath)

    if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) {
        throw [InvalidOperationException]::new('TRANSLATE_NOT_CONFIGURED')
    }
    try {
        $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
        $region = ([string] $configuration.region).Trim().ToLowerInvariant()
        if ($region -notmatch '^[a-z0-9]+$') { throw 'invalid region' }
        return $region
    } catch {
        throw [InvalidOperationException]::new('TRANSLATE_NOT_CONFIGURED')
    }
}

function Get-CopyQTranslationFailureReason {
    param([Parameter(Mandatory)] $ErrorRecord)

    try {
        $statusCode = [int] $ErrorRecord.Exception.Response.StatusCode
    } catch {
        return 'TRANSLATE_FAILED'
    }
    if ($statusCode -in 401, 403) { return 'TRANSLATE_AUTH_FAILED' }
    if ($statusCode -eq 400) { return 'TRANSLATE_REGION_FAILED' }
    if ($statusCode -eq 429) { return 'TRANSLATE_RATE_LIMITED' }
    return 'TRANSLATE_FAILED'
}

function Invoke-CopyQTranslator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Text,

        [Parameter(Mandatory)]
        [string] $CredentialPath,

        [string] $Endpoint = 'https://api.cognitive.microsofttranslator.com',

        [string] $Region = 'germanywestcentral'
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw [InvalidOperationException]::new('TRANSLATE_EMPTY')
    }

    $plainKey = Get-CopyQTranslatorKey -CredentialPath $CredentialPath
    try {
        $baseUri = [Uri] $Endpoint
        if ($baseUri.Scheme -ne 'https') { throw 'HTTPS required' }
        $uri = $Endpoint.TrimEnd('/') + '/translate?api-version=3.0&to=en'
        $headers = @{
            'Ocp-Apim-Subscription-Key' = $plainKey
            'Ocp-Apim-Subscription-Region' = $Region
        }
        $body = ConvertTo-Json -InputObject @(@{ Text = $Text }) -Compress
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri $uri `
            -Headers $headers `
            -ContentType 'application/json; charset=UTF-8' `
            -Body $body
    } catch {
        $reason = Get-CopyQTranslationFailureReason -ErrorRecord $_
        throw [InvalidOperationException]::new($reason)
    } finally {
        $plainKey = $null
    }

    try {
        $translated = [string] $response[0].translations[0].text
    } catch {
        throw [InvalidOperationException]::new('TRANSLATE_EMPTY')
    }
    if ([string]::IsNullOrWhiteSpace($translated)) {
        throw [InvalidOperationException]::new('TRANSLATE_EMPTY')
    }
    return $translated
}

Export-ModuleMember -Function Set-CopyQTranslatorCredential, Set-CopyQTranslatorRegion, Get-CopyQTranslatorRegion, Invoke-CopyQTranslator
