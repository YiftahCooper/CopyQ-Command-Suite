#Requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('Wizard','Preview','Install','Verify','ExportProfile','Restore')][string] $Mode='Wizard',
    [string] $ProfilePath, [string] $ReceiptPath, [switch] $ConfirmInstall,
    [switch] $UiSmokeTest
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1') -Force
if ($Mode -eq 'Wizard') {
    . (Join-Path $PSScriptRoot 'setup/wizard.ps1')
    $view=New-CopyQSetupWizard $root
    if ($UiSmokeTest) {
        [pscustomobject]@{Commands=$view.Grid.Rows.Count;Actions=@($view.Actions)}
        $view.Form.Dispose(); return
    }
    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run setup as your normal Windows user, not as administrator.' }
    [void]$view.Form.ShowDialog();$view.Form.Dispose();return
}
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'NORMAL_USER_REQUIRED' }
$context=New-CopyQSetupContext -Root $root
if ($Mode -eq 'ExportProfile') {
    if (-not $ProfilePath) { throw 'PROFILE_PATH_REQUIRED' }
    Save-CopyQSetupProfile (Export-CopyQSetupProfile $context) $ProfilePath
    'PROFILE_EXPORTED';return
}
if ($Mode -eq 'Restore') {
    if (-not $ConfirmInstall -or -not $ReceiptPath) { throw 'RESTORE_CONFIRMATION_REQUIRED' }
    Restore-CopyQSetupCommands $context $ReceiptPath | ConvertTo-Json;return
}
$profile=if ($ProfilePath) {Read-CopyQSetupProfile $ProfilePath} else {New-CopyQSetupProfile}
if ($Mode -eq 'Verify') {Test-CopyQSetupInstallation $context $profile | ConvertTo-Json -Depth 8;return}
$preview=Get-CopyQSetupPreview $context $profile
if ($Mode -eq 'Preview') {
    $preview | Select-Object added,updated,unchanged,replacedProtection,preserved,selected,needsRestart,missingDependencies,packageDigest | ConvertTo-Json -Depth 5
    return
}
if (-not $ConfirmInstall) {throw 'INSTALL_CONFIRMATION_REQUIRED'}
Install-CopyQSetupSelection $context $preview | ConvertTo-Json
