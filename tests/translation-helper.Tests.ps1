$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:ModulePath = Join-Path $script:RepoRoot 'modules\CopyQ.Translation.psm1'

Describe 'CopyQ Azure translation credential and response boundary' {
    BeforeEach {
        Import-Module $script:ModulePath -Force
        $script:PrivateRoot = [IO.Path]::GetFullPath((Join-Path $env:TEMP ('copyq-translation-' + [guid]::NewGuid().ToString('N'))))
        $script:CredentialPath = Join-Path $script:PrivateRoot 'azure-key.dpapi'
        $script:ConfigurationPath = Join-Path $script:PrivateRoot 'translator.json'
        $script:PlainKey = 'fixture-key-never-persisted'
        $secureKey = ConvertTo-SecureString $script:PlainKey -AsPlainText -Force
        Set-CopyQTranslatorCredential -SecureKey $secureKey -CredentialPath $script:CredentialPath | Out-Null
    }

    AfterEach {
        Remove-Module CopyQ.Translation -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $script:PrivateRoot) {
            Remove-Item -LiteralPath $script:PrivateRoot -Recurse -Force
        }
    }

    It 'stores a current-user encrypted key without plaintext' {
        Test-Path -LiteralPath $script:CredentialPath | Should Be $true
        $ciphertext = Get-Content -LiteralPath $script:CredentialPath -Raw
        $ciphertext | Should Not Match ([regex]::Escape($script:PlainKey))
        $ciphertext.Trim().Length | Should BeGreaterThan 40
    }

    It 'stores the Azure region separately without credential material' {
        Set-CopyQTranslatorRegion -Region 'germanywestcentral' -ConfigurationPath $script:ConfigurationPath | Out-Null
        $configuration = Get-Content -LiteralPath $script:ConfigurationPath -Raw | ConvertFrom-Json
        $configuration.region | Should BeExactly 'germanywestcentral'
        (Get-Content -LiteralPath $script:ConfigurationPath -Raw) | Should Not Match ([regex]::Escape($script:PlainKey))
        Get-CopyQTranslatorRegion -ConfigurationPath $script:ConfigurationPath | Should BeExactly 'germanywestcentral'
    }

    It 'posts exact Azure Translator input and returns only translated text' {
        Mock Invoke-RestMethod -ModuleName CopyQ.Translation -Verifiable -ParameterFilter {
            $Method -eq 'Post' -and
            $Uri -eq 'https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=en' -and
            $Headers['Ocp-Apim-Subscription-Key'] -eq $script:PlainKey -and
            $Headers['Ocp-Apim-Subscription-Region'] -eq 'germanywestcentral' -and
            $ContentType -eq 'application/json; charset=UTF-8' -and
            (($Body | ConvertFrom-Json)[0].Text) -eq 'שלום'
        } {
            return @([pscustomobject]@{
                detectedLanguage = [pscustomobject]@{ language = 'he'; score = 1.0 }
                translations = @([pscustomobject]@{ text = 'Hello'; to = 'en' })
            })
        }

        $result = Invoke-CopyQTranslator -Text 'שלום' -CredentialPath $script:CredentialPath

        $result | Should BeExactly 'Hello'
        Assert-VerifiableMocks
    }

    It 'reports a missing credential without including the path' {
        $missing = Join-Path $script:PrivateRoot 'missing.dpapi'
        { Invoke-CopyQTranslator -Text 'שלום' -CredentialPath $missing } |
            Should Throw 'TRANSLATE_NOT_CONFIGURED'
    }

    It 'maps an HTTP failure to a static reason code' {
        Mock Invoke-RestMethod -ModuleName CopyQ.Translation { throw 'network detail that must not escape' }
        { Invoke-CopyQTranslator -Text 'שלום' -CredentialPath $script:CredentialPath } |
            Should Throw 'TRANSLATE_FAILED'
    }

    It 'maps HTTP <StatusCode> to <Reason> without exposing service details' -TestCases @(
        @{ StatusCode = 401; Reason = 'TRANSLATE_AUTH_FAILED' }
        @{ StatusCode = 403; Reason = 'TRANSLATE_AUTH_FAILED' }
        @{ StatusCode = 400; Reason = 'TRANSLATE_REGION_FAILED' }
        @{ StatusCode = 429; Reason = 'TRANSLATE_RATE_LIMITED' }
    ) {
        param($StatusCode, $Reason)
        $module = Get-Module CopyQ.Translation
        $actual = & $module {
            param($Code)
            $response = [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode] ([int] $Code))
            try { throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('private service detail', $response) }
            catch { Get-CopyQTranslationFailureReason -ErrorRecord $_ }
        } $StatusCode
        $actual | Should Be $Reason
    }

    It 'rejects an empty or malformed successful response' {
        $moduleSource = Get-Content -LiteralPath $script:ModulePath -Raw
        $moduleSource | Should Match '\$response\[0\]\.translations\[0\]\.text'
        $moduleSource | Should Match '\[string\]::IsNullOrWhiteSpace\(\$translated\)'
        $moduleSource | Should Match "InvalidOperationException\]::new\('TRANSLATE_EMPTY'\)"
    }

    It 'keeps source text and failure details out of the CopyQ helper output' {
        $missing = Join-Path $script:PrivateRoot 'missing.dpapi'
        $helper = Join-Path $script:RepoRoot 'scripts\Invoke-CopyQAzureTranslation.ps1'
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        $startInfo.FileName = if ($pwsh) { $pwsh.Source } else { Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
        $startInfo.ArgumentList.Add('-NoLogo')
        $startInfo.ArgumentList.Add('-NoProfile')
        $startInfo.ArgumentList.Add('-NonInteractive')
        $startInfo.ArgumentList.Add('-File')
        $startInfo.ArgumentList.Add($helper)
        $startInfo.ArgumentList.Add('-CredentialPath')
        $startInfo.ArgumentList.Add($missing)
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false

        $process = [Diagnostics.Process]::Start($startInfo)
        $encodedSource = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('שלום private source'))
        $process.StandardInput.Write($encodedSource)
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        $process.ExitCode | Should Be 1
        $stdout | Should BeNullOrEmpty
        $stderr | Should BeExactly 'TRANSLATE_NOT_CONFIGURED'
        $stderr | Should Not Match 'שלום|private source|missing\.dpapi'
    }

    It 'uses Base64-wrapped UTF-8 for the complete helper transport boundary' {
        $helper = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot 'scripts\Invoke-CopyQAzureTranslation.ps1')
        $helper | Should Match '\[Convert\]::FromBase64String'
        $helper | Should Match '\[Text\.Encoding\]::UTF8\.GetString'
        $helper | Should Match '\[Text\.Encoding\]::UTF8\.GetBytes'
        $helper | Should Match '\[Convert\]::ToBase64String'
        $helper | Should Not Match '\$sourceText\s*=\s*\[Console\]::In\.ReadToEnd\(\)'
        $helper | Should Match 'Get-CopyQTranslatorRegion'
    }
}
