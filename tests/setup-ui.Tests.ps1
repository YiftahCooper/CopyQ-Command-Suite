$ErrorActionPreference='Stop'
Get-Module CopyQ.Setup -All | Remove-Module -Force
Import-Module (Join-Path $PSScriptRoot '../modules/CopyQ.Setup.psm1') -Force
function Invoke-WizardButton($View,[string] $Label) {
    $button=$View.Form.Controls[0].Controls[2].Controls | Where-Object Text -eq $Label
    if($null -eq $button){throw "BUTTON_NOT_FOUND: $Label"}
    [void]$button.GetType().GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($button,@([EventArgs]::Empty))
}
Describe 'Reviewed installation safety in the real wizard callbacks' {
    It 'handles <Mode> without confusing installation with verification' -TestCases @(@{Mode='cancel'},@{Mode='bad-check'},@{Mode='check-timeout'},@{Mode='stale'}) {
        param($Mode)
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        Mock Invoke-CopyQSetupProcess -ModuleName CopyQ.Setup {return 'CopyQ Clipboard Manager v16.0.0'}
        Mock Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup {
            if($Request.action -eq 'snapshot'){return @{inventory=@()}}
            [pscustomobject]@{before='old';candidate='new';added=@('canonical.smart-title');updated=@();unchanged=@();replacedProtection=@();preserved=37;selected=$Request.ids;needsRestart=$false}
        }
        Mock Get-CopyQSetupDependencyStatus -ModuleName CopyQ.Setup {return @{ready=$true;missingDependencies=@()}}
        # These callbacks survive the test's invocation scope, just like native
        # form events. Explicit closures avoid Pester 3's scoped modal proxies.
        $fixture=@{Mode=$Mode;Installs=0;Checks=0}
        Set-Item Function:Confirm-CopyQWizardChange -Value {$fixture.Mode -ne 'cancel'}.GetNewClosure()
        Set-Item Function:Install-CopyQSetupSelection -Value {
            param($Context,$Preview)
            $fixture.Installs++
            if($fixture.Mode -eq 'stale'){throw 'COMMAND_STATE_CHANGED'}
            [pscustomobject]@{result='installed';receipt='synthetic/receipt.json';selected=@('canonical.smart-title')}
        }.GetNewClosure()
        Set-Item Function:Test-CopyQSetupInstallation -Value {
            param($Context,$Profile)
            $fixture.Checks++
            if($fixture.Mode -eq 'check-timeout'){throw 'COPYQ_TIMEOUT'}
            [pscustomobject]@{definitionsVerified=$true;helpersPassed=($fixture.Mode -ne 'bad-check');dependencyChecksRun=$true;missingDependencies=@();helperChecks=@()}
        }.GetNewClosure()
        $view=New-CopyQSetupWizard $root
        try{
            ($view.Grid.Rows | Where-Object Tag -eq 'canonical.smart-title').Cells[0].Value=$true
            Invoke-WizardButton $view 'Review changes';Invoke-WizardButton $view 'Install / update'
            $summary=$view.Form.Controls.Find('summaryText',$true)[0].Text
            if($Mode -eq 'cancel'){
                $fixture.Installs | Should Be 0;$fixture.Checks | Should Be 0
                $view.Form.Controls.Find('applyButton',$true)[0].Enabled | Should Be $true
            }elseif($Mode -eq 'stale'){
                $summary | Should Match 'changed after review';$fixture.Checks | Should Be 0
                $view.Form.Controls.Find('applyButton',$true)[0].Enabled | Should Be $false
            }else{
                $summary | Should Match $(if($Mode -eq 'bad-check'){'needs attention'}else{'Commands were installed, but checking did not finish'})
                $summary | Should Not Match 'automatic checks passed'
                $view.Form.Controls.Find('applyButton',$true)[0].Enabled | Should Be $false
                Invoke-WizardButton $view 'Check installation again'
                $fixture.Installs | Should Be 1;$fixture.Checks | Should Be 2
            }
        }finally{$view.Form.Dispose()}
    }
}
Describe 'Plain-language setup results' {
    BeforeEach {
        Import-Module (Join-Path $PSScriptRoot '../modules/CopyQ.Setup.psm1')
        . (Join-Path $PSScriptRoot '../scripts/setup/wizard.ps1')
        $catalog=@([pscustomobject]@{id='canonical.dispatcher';name='Clipboard Router'},[pscustomobject]@{id='canonical.ocr';name='Copy Text in Image'})
    }
    It 'names the update and preserved commands without asking the user to interpret JSON' {
        $preview=[pscustomobject]@{before='old';candidate='new';added=@();updated=@('canonical.dispatcher');unchanged=@();replacedProtection=@();preserved=37;selected=@('canonical.dispatcher');needsRestart=$false;missingDependencies=@()}
        $result=Get-CopyQWizardReview $preview $catalog
        $result.Ready | Should Be $true
        $result.HasChanges | Should Be $true
        $result.Text | Should Match 'Update: Clipboard Router'
        $result.Text | Should Match '37 other commands'
        $result.Text | Should Not Match 'canonical.dispatcher|"updated"'
        $preview.missingDependencies=@('Tesseract with eng+heb')
        $blocked=Get-CopyQWizardReview $preview $catalog
        $blocked.Ready | Should Be $false
        $blocked.Text | Should Match 'Cannot install yet|Tesseract|uncheck'
    }
    It 'does not claim success when definitions, helpers or dependency checks failed' {
        foreach($failure in @('definitionsVerified','helpersPassed','dependencyChecksRun','missingDependencies')) {
            $check=@{definitionsVerified=$true;helpersPassed=$true;dependencyChecksRun=$true;missingDependencies=@();helperChecks=@()}
            if($failure -eq 'missingDependencies'){$check[$failure]=@('marked')}else{$check[$failure]=$false}
            $result=Get-CopyQWizardVerification ([pscustomobject]$check) $false
            $result.Passed | Should Be $false
            $result.Text | Should Match 'needs attention'
        }
        $good=[pscustomobject]@{definitionsVerified=$true;helpersPassed=$true;dependencyChecksRun=$true;missingDependencies=@();helperChecks=@()}
        (Get-CopyQWizardVerification $good $false).Text | Should Match 'automatic checks passed'
        (Get-CopyQWizardVerification $good $true).Text | Should Match 'restart CopyQ'
        (Get-CopyQWizardVerification $good $false).Text | Should Match 'Not tested: actual copying and pasting'
    }
}
Describe 'Setup wizard construction' {
    It 'opens with nothing selected and cannot install before a review' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        $view=New-CopyQSetupWizard $root
        try {
            @($view.Grid.Rows | Where-Object {$_.Cells[0].Value}).Count | Should Be 0
            $install=$view.Form.Controls.Find('applyButton',$true)[0]
            $install.Enabled | Should Be $false
        } finally {$view.Form.Dispose()}
    }
    It 'constructs the command selector and public actions without contacting CopyQ' {
        $view=& (Join-Path $PSScriptRoot '../scripts/Setup-CopyQ.ps1') -UiSmokeTest
        $view.Commands | Should Be 19
        ($view.Actions -contains 'Review changes') | Should Be $true
        ($view.Actions -contains 'Install / update') | Should Be $true
        ($view.Actions -contains 'Save profile') | Should Be $true
    }
    It 'runs real preset button callbacks without changing installed commands' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
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
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        $profile=New-CopyQSetupProfile -Commands @('canonical.smart-title','canonical.no-longer-available')
        {New-CopyQSetupWizard -Root $root -InitialProfile $profile} | Should Throw 'UNKNOWN_COMMAND'
    }
    It 'unchecks all commands without clearing shortcut edits' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        $view=New-CopyQSetupWizard $root
        try {
            $row=$view.Grid.Rows | Where-Object Tag -eq 'canonical.smart-title'
            $row.Cells[0].Value=$true
            $row.Cells[2].Value='Ctrl+Shift+T'
            $row.Cells[3].Value='-'
            $button=$view.Form.Controls[0].Controls[2].Controls | Where-Object Text -eq 'Uncheck all'
            ($null -ne $button) | Should Be $true
            foreach ($repeat in 1..2) {
                [void]$button.GetType().GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($button,@([EventArgs]::Empty))
                @($view.Grid.Rows | Where-Object {$_.Cells[0].Value}).Count | Should Be 0
                $row.Cells[2].Value | Should Be 'Ctrl+Shift+T'
                $row.Cells[3].Value | Should Be '-'
            }
            $row.Cells[0].Value=$true
            @($view.Grid.Rows | Where-Object {$_.Cells[0].Value}).Count | Should Be 1
        } finally {$view.Form.Dispose()}
    }
    It 'previews the installed selection without collapsing empty or single shortcut arrays' {
        $root=Split-Path -Parent $PSScriptRoot
        # The ZIP test also imports an extracted copy; Pester needs one target.
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
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
            return [pscustomobject]@{before='same';candidate='same';added=@();updated=@();unchanged=@();replacedProtection=@();preserved=0;selected=$Request.ids;needsRestart=$false}
        }
        $view=New-CopyQSetupWizard $root
        try {
            $panel=$view.Form.Controls[0].Controls[2]
            foreach ($label in @('Select installed commands','Review changes')) {
                $button=$panel.Controls | Where-Object Text -eq $label
                [void]$button.GetType().GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($button,@([EventArgs]::Empty))
                $view.Form.Controls.Find('summaryText',$true)[0].Text | Should Not Match 'PROFILE_SHORTCUT_INVALID'
            }
            $result=$view.Form.Controls.Find('technicalDetails',$true)[0].Text | ConvertFrom-Json
            (($result.selected | Sort-Object) -join ';') | Should Be ((@($loadedProfile.commands)+@('canonical.dispatcher','canonical.undoable-delete-listener') | Sort-Object) -join ';')
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
    It 'retains existing shortcuts for a single-command update without a separate discovery click' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        Mock Invoke-CopyQSetupProcess -ModuleName CopyQ.Setup {return 'CopyQ Clipboard Manager v16.0.0'}
        Mock Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup {
            if($Request.action -eq 'snapshot'){return @{inventory=@(@{id='canonical.smart-title';local=@('Ctrl+Shift+T');global=@()})}}
            [pscustomobject]@{before='old';candidate='new';added=@();updated=@('canonical.smart-title');unchanged=@();replacedProtection=@();preserved=37;selected=$Request.ids;needsRestart=$false}
        }
        $view=New-CopyQSetupWizard $root
        try{
            ($view.Grid.Rows | Where-Object Tag -eq 'canonical.smart-title').Cells[0].Value=$true
            Invoke-WizardButton $view 'Review changes'
            if($view.Form.Controls.Find('summaryText',$true)[0].Text -like 'Setup stopped*'){throw $view.Form.Controls.Find('technicalDetails',$true)[0].Text}
            $view.Form.Controls.Find('applyButton',$true)[0].Enabled | Should Be $true
            $view.Form.Controls.Find('summaryText',$true)[0].Text | Should Match 'Update: To Title Case'
            Assert-MockCalled Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup -Times 1 -Exactly -ParameterFilter {$Request.action -eq 'preview' -and $Request.shortcuts['canonical.smart-title'].local[0] -ceq 'Ctrl+Shift+T' -and $Request.shortcuts['canonical.smart-title'].global.Count -eq 0}
            ($view.Grid.Rows | Where-Object Tag -eq 'canonical.smart-title').Cells[2].Value='Ctrl+Alt+T'
            $view.Form.Controls.Find('applyButton',$true)[0].Enabled | Should Be $false
            $view.Form.Controls.Find('summaryText',$true)[0].Text | Should Match 'Selection changed'
            Invoke-WizardButton $view 'Install / update'
            $view.Form.Controls.Find('summaryText',$true)[0].Text | Should Match 'not been reviewed'
        }finally{$view.Form.Dispose()}
    }
    It 'inherits current shortcuts on each review, including after opening Advanced' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        Mock Invoke-CopyQSetupProcess -ModuleName CopyQ.Setup {return 'CopyQ Clipboard Manager v16.0.0'}
        Mock Get-CopyQSetupDependencyStatus -ModuleName CopyQ.Setup {return @{ready=$true;missingDependencies=@()}}
        Mock Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup {
            if($Request.action -eq 'snapshot'){return @{inventory=@(@{id='canonical.smart-title';local=@('Ctrl+T');global=@()})}}
            [pscustomobject]@{before='old';candidate='new';added=@();updated=@('canonical.smart-title');unchanged=@();replacedProtection=@();preserved=37;selected=$Request.ids;needsRestart=$false}
        }
        $view=New-CopyQSetupWizard $root
        try{
            $row=$view.Grid.Rows | Where-Object Tag -eq 'canonical.smart-title'
            $row.Cells[0].Value=$true
            Invoke-WizardButton $view 'Review changes'
            $view.Form.Controls.Find('advancedOptions',$true)[0].Checked=$true
            $row.Cells[2].Value | Should Be ''
            $row.Cells[2].ToolTipText | Should Match 'Ctrl\+T'
            Mock Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup {
                if($Request.action -eq 'snapshot'){return @{inventory=@(@{id='canonical.smart-title';local=@('Ctrl+Shift+T');global=@()},@{id='canonical.regex-search';local=@();global=@()})}}
                [pscustomobject]@{before='old';candidate='new';added=@();updated=@('canonical.smart-title');unchanged=@();replacedProtection=@();preserved=37;selected=$Request.ids;needsRestart=$false}
            }
            Invoke-WizardButton $view 'Review changes'
            Assert-MockCalled Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup -Scope It -Times 1 -Exactly -ParameterFilter {$Request.action -eq 'preview' -and $Request.shortcuts['canonical.smart-title'].local[0] -ceq 'Ctrl+Shift+T'}
            ($view.Grid.Rows | Where-Object Tag -eq 'canonical.regex-search').Cells[4].Value | Should Be 'Installed'
            $row.Cells[2].ToolTipText | Should Match 'Ctrl\+Shift\+T'
            $row.Cells[2].Value='Ctrl+Alt+T'
            Invoke-WizardButton $view 'Review changes'
            Assert-MockCalled Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup -Scope It -Times 1 -Exactly -ParameterFilter {$Request.action -eq 'preview' -and $Request.shortcuts['canonical.smart-title'].local[0] -ceq 'Ctrl+Alt+T'}
        }finally{$view.Form.Dispose()}
    }
    It 'blocks missing prerequisites and unchanged selections without presenting an install action' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        Mock Invoke-CopyQSetupProcess -ModuleName CopyQ.Setup {return 'CopyQ Clipboard Manager v16.0.0'}
        Mock Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup {
            if($Request.action -eq 'snapshot'){return @{inventory=@()}}
            [pscustomobject]@{before='same';candidate='same';added=@();updated=@();unchanged=@('canonical.ocr');replacedProtection=@();preserved=37;selected=$Request.ids;needsRestart=$false}
        }
        Mock Get-CopyQSetupDependencyStatus -ModuleName CopyQ.Setup {return @{ready=$false;missingDependencies=@('Tesseract with eng+heb')}}
        $view=New-CopyQSetupWizard $root
        try{
            ($view.Grid.Rows | Where-Object Tag -eq 'canonical.ocr').Cells[0].Value=$true
            Invoke-WizardButton $view 'Review changes'
            $view.Form.Controls.Find('applyButton',$true)[0].Enabled | Should Be $false
            $view.Form.Controls.Find('summaryText',$true)[0].Text | Should Match 'Cannot install yet'
        }finally{$view.Form.Dispose()}
    }
    It 'installs the reviewed selection and checks it automatically without another button click' {
        $root=Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1')
        . (Join-Path $root 'scripts/setup/wizard.ps1')
        Mock Invoke-CopyQSetupProcess -ModuleName CopyQ.Setup {return 'CopyQ Clipboard Manager v16.0.0'}
        Mock Invoke-CopyQSetupBridge -ModuleName CopyQ.Setup {
            if($Request.action -eq 'snapshot'){return @{inventory=@()}}
            [pscustomobject]@{before='old';candidate='new';added=@('canonical.smart-title');updated=@();unchanged=@();replacedProtection=@();preserved=37;selected=$Request.ids;needsRestart=$false}
        }
        Mock Confirm-CopyQWizardChange {return $true}
        Mock Get-CopyQSetupDependencyStatus -ModuleName CopyQ.Setup {return @{ready=$true;missingDependencies=@()}}
        Mock Install-CopyQSetupSelection {return [pscustomobject]@{result='installed';receipt='synthetic/receipt.json';selected=@('canonical.smart-title')}}
        Mock Test-CopyQSetupInstallation {return [pscustomobject]@{definitionsVerified=$true;helpersPassed=$true;dependencyChecksRun=$true;missingDependencies=@();helperChecks=@()}}
        $view=New-CopyQSetupWizard $root
        try{
            ($view.Grid.Rows | Where-Object Tag -eq 'canonical.smart-title').Cells[0].Value=$true
            Invoke-WizardButton $view 'Review changes'
            if(-not $view.Form.Controls.Find('applyButton',$true)[0].Enabled){throw ('REVIEW_NOT_READY: '+$view.Form.Controls.Find('summaryText',$true)[0].Text+' '+$view.Form.Controls.Find('technicalDetails',$true)[0].Text)}
            Invoke-WizardButton $view 'Install / update'
            if($view.Form.Controls.Find('summaryText',$true)[0].Text -like 'Setup stopped*'){throw $view.Form.Controls.Find('technicalDetails',$true)[0].Text}
            $view.Form.Controls.Find('summaryText',$true)[0].Text | Should Match 'Installed - automatic checks passed'
            $view.Form.Controls.Find('applyButton',$true)[0].Enabled | Should Be $false
            Assert-MockCalled Test-CopyQSetupInstallation -Times 1 -Exactly
        }finally{$view.Form.Dispose()}
    }
}
