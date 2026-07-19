$ErrorActionPreference = 'Stop'

Describe 'Public dependency and translation installation helpers' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:DependencyScript = Join-Path $script:RepoRoot 'scripts\Test-Dependencies.ps1'
        $script:InstallScript = Join-Path $script:RepoRoot 'scripts\Install-CopyQTranslation.ps1'
    }

    BeforeEach {
        $script:PrivateRoot = Join-Path $env:TEMP ('copyq-public-helper-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:PrivateRoot | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:PrivateRoot) {
            Remove-Item -LiteralPath $script:PrivateRoot -Recurse -Force
        }
    }

    It 'reports every optional dependency as structured read-only data' {
        Test-Path -LiteralPath $script:DependencyScript -PathType Leaf | Should -BeTrue
        $before = @(Get-ChildItem -LiteralPath $script:PrivateRoot -Recurse -Force).Count
        $json = & $script:DependencyScript `
            -LocalAppData $script:PrivateRoot `
            -AppData $script:PrivateRoot `
            -ProgramFiles $script:PrivateRoot `
            -AsJson
        $result = $json | ConvertFrom-Json
        foreach ($name in @('CopyQ', 'Marked', 'Python', 'Pygments', 'Tesseract', 'TesseractLanguages', 'PowerShell', 'Moonlander')) {
            $result.PSObject.Properties.Name | Should -Contain $name
        }
        @(Get-ChildItem -LiteralPath $script:PrivateRoot -Recurse -Force).Count | Should -Be $before
        $json | Should -Not -Match 'azure-key|Subscription-Key|Bearer '
    }

    It 'copies only the portable translation runtime when configuration is skipped' {
        Test-Path -LiteralPath $script:InstallScript -PathType Leaf | Should -BeTrue
        $destination = Join-Path $script:PrivateRoot 'translation'
        $result = & $script:InstallScript -DestinationRoot $destination -SkipConfiguration
        $result | Should -BeExactly 'COPYQ_TRANSLATION_INSTALLED'
        @(Get-ChildItem -LiteralPath $destination -File).Name | Sort-Object | Should -Be @(
            'CopyQ.Translation.psm1',
            'Invoke-CopyQAzureTranslation.ps1',
            'Set-CopyQAzureTranslator.ps1'
        )
    }
}
