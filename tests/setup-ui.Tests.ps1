$ErrorActionPreference='Stop'
Describe 'Setup wizard construction' {
    It 'constructs the command selector and public actions without contacting CopyQ' {
        $view=& (Join-Path $PSScriptRoot '../scripts/Setup-CopyQ.ps1') -UiSmokeTest
        $view.Commands | Should Be 19
        ($view.Actions -contains 'Preview changes') | Should Be $true
        ($view.Actions -contains 'Install selected') | Should Be $true
        ($view.Actions -contains 'Save profile') | Should Be $true
    }
    It 'runs real preset button callbacks without changing installed commands' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1') -Force
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        $view=New-CopyQSetupWizard $root
        try {
            $panel=$view.Form.Controls[0].Controls[2]
            $button=$panel.Controls | Where-Object Text -eq 'Protection only'
            $method=$button.GetType().GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
            [void]$method.Invoke($button,@([EventArgs]::Empty))
            $selected=@($view.Grid.Rows | Where-Object {$_.Cells[0].Value})
            $selected.Count | Should Be 1
            $selected[0].Tag | Should Be 'canonical.secret-protection'
        } finally {$view.Form.Dispose()}
    }
    It 'rejects an unavailable profile command instead of silently dropping it' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1') -Force
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        $profile=New-CopyQSetupProfile -Commands @('canonical.smart-title','canonical.no-longer-available')
        {New-CopyQSetupWizard -Root $root -InitialProfile $profile} | Should Throw 'UNKNOWN_COMMAND'
    }
    It 'previews the installed selection without collapsing empty or single shortcut arrays' {
        $root=Split-Path -Parent $PSScriptRoot
        # The ZIP test also imports an extracted copy; Pester needs one target.
        Get-Module CopyQ.Setup -All | Remove-Module -Force
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1') -Force
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        $loadedProfile=New-CopyQSetupProfile -Commands @('canonical.undo-delete','canonical.show-frequent','canonical.smart-title')
        $loadedProfile.shortcuts=@{
            'canonical.undo-delete'=@{local=@('Ctrl+Z');global=@()}
            'canonical.show-frequent'=@{local=@();global=@('Meta+Shift+F')}
            'canonical.smart-title'=@{local=@('Ctrl+T','Ctrl+Shift+T');global=@()}
        }
        Mock Invoke-CopyQSetupProcess -ModuleName CopyQ.Setup {return 'CopyQ Clipboard Manager v16.0.0'}
        Mock Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup {
            if ($Request.action -eq 'snapshot') {
                return @{inventory=@(
                    @{id='canonical.undo-delete';local=@('Ctrl+Z');global=@()},
                    @{id='canonical.show-frequent';local=@();global=@('Meta+Shift+F')},
                    @{id='canonical.smart-title';local=@('Ctrl+T','Ctrl+Shift+T');global=@()}
                )}
            }
            return [pscustomobject]@{added=@();updated=@();unchanged=@();replacedProtection=@();preserved=0;selected=$Request.ids;needsRestart=$false}
        }
        $view=New-CopyQSetupWizard $root
        try {
            $panel=$view.Form.Controls[0].Controls[2]
            foreach ($label in @('Read installed selection','Preview changes')) {
                $button=$panel.Controls | Where-Object Text -eq $label
                [void]$button.GetType().GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($button,@([EventArgs]::Empty))
                $view.Form.Controls[0].Controls[3].Text | Should Not Match 'PROFILE_SHORTCUT_INVALID'
            }
            $result=$view.Form.Controls[0].Controls[3].Text | ConvertFrom-Json
            (($result.selected | Sort-Object) -join ';') | Should Be (($loadedProfile.commands | Sort-Object) -join ';')
            Assert-MockCalled Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup -Times 1 -Exactly -ParameterFilter {
                $Request.action -eq 'preview' -and
                $Request.shortcuts['canonical.undo-delete'].local.Count -eq 1 -and
                $Request.shortcuts['canonical.undo-delete'].local[0] -ceq 'Ctrl+Z' -and
                $Request.shortcuts['canonical.undo-delete'].global.Count -eq 0 -and
                $Request.shortcuts['canonical.show-frequent'].local.Count -eq 0 -and
                $Request.shortcuts['canonical.show-frequent'].global[0] -ceq 'Meta+Shift+F' -and
                ($Request.shortcuts['canonical.smart-title'].local -join ';') -ceq 'Ctrl+T;Ctrl+Shift+T'
            }
        } finally {$view.Form.Dispose()}
    }
}
