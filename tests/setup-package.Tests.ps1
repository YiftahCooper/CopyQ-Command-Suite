$ErrorActionPreference='Stop'
Describe 'Setup release ZIP' {
    It 'contains exactly the public allowlist and extracts into a working package' {
        $root=Split-Path -Parent $PSScriptRoot
        $result=& (Join-Path $root 'scripts/Build-SetupPackage.ps1') -OutputDirectory $TestDrive
        $extract=Join-Path $TestDrive 'extracted'
        Expand-Archive -LiteralPath $result.Path -DestinationPath $extract
        $expected=@(Get-Content (Join-Path $root 'PUBLIC-FILES.txt'))
        $actual=@(Get-ChildItem $extract -Recurse -File | ForEach-Object {[IO.Path]::GetRelativePath($extract,$_.FullName).Replace('\','/')})
        @(Compare-Object $expected $actual).Count | Should Be 0
        Import-Module (Join-Path $extract 'modules/CopyQ.Setup.psm1') -Force
        (Get-CopyQSetupPackage $extract).Catalog.Count | Should Be 19
        $view=& (Join-Path $extract 'scripts/Setup-CopyQ.ps1') -UiSmokeTest
        $view.Commands | Should Be 19
        $again=& (Join-Path $root 'scripts/Build-SetupPackage.ps1') -OutputDirectory $TestDrive
        $again.Sha256 | Should Be $result.Sha256
    }
}
