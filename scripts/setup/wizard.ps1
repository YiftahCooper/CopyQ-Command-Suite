function Get-CopyQWizardReview($Preview, $Catalog) {
    $names=@{}; foreach($entry in $Catalog){$names[$entry.id]=$entry.name}
    $lines=[Collections.Generic.List[string]]::new()
    $missing=@($Preview.missingDependencies | Where-Object {$_})
    $changed=$Preview.before -cne $Preview.candidate
    $lines.Add($(if($missing.Count){'Cannot install yet - required tools are missing.'}elseif($changed){'Ready to install / update.'}else{'Already up to date - no changes needed.'}))
    foreach($group in @(@('added','Add'),@('updated','Update'),@('replacedProtection','Replace protection'),@('unchanged','Already up to date'))){
        foreach($id in @($Preview.($group[0]))){if($id){$label=if($names.ContainsKey($id)){$names[$id]}else{$id};$lines.Add($group[1]+': '+$label)}}
    }
    if($changed -and -not @($Preview.added+$Preview.updated+$Preview.replacedProtection).Count){$lines.Add('Update the reviewed command ordering.')}
    $lines.Add("$($Preview.preserved) other commands stay unchanged.")
    if($Preview.selected -contains 'canonical.undo-delete'){$lines.Add('Undo uses both Move to Trash (Undoable) and Undo Delete; both are selected.')}
    if($Preview.selected -contains 'canonical.show-frequent'){$lines.Add('Show Frequent requires Clipboard Router; both are selected.')}
    if($missing.Count){
        $lines.Add('Missing: '+($missing -join '; '))
        $lines.Add('Next: install these tools or uncheck the affected commands, then review again.')
    }else{
        $lines.Add('Required tools: available.')
        $lines.Add('Restart required: '+$(if($Preview.needsRestart){'yes - exit CopyQ completely and start it again after installation.'}else{'no.'}))
        if($changed){$lines.Add('Next: click Install / update. Selected command edits will be replaced; a command-only backup is saved first.')}
    }
    [pscustomobject]@{Ready=($missing.Count -eq 0);HasChanges=$changed;Text=($lines -join "`r`n")}
}

function Get-CopyQWizardVerification($Check, [bool] $NeedsRestart) {
    $missing=@($Check.missingDependencies | Where-Object {$_})
    $passed=$Check.definitionsVerified -and $Check.helpersPassed -and $Check.dependencyChecksRun -and $missing.Count -eq 0
    $lines=[Collections.Generic.List[string]]::new()
    $lines.Add($(if(-not $passed){'Installation needs attention - automatic checks did not pass.'}elseif($NeedsRestart){'Installed - restart CopyQ to activate the Undo changes.'}else{'Installed - automatic checks passed.'}))
    if(-not $Check.definitionsVerified){$lines.Add('The installed commands do not match this selection. Review the selection before installing again.')}
    elseif(-not $Check.helpersPassed){$lines.Add('An embedded command check failed. Open Technical details for the affected command.')}
    elseif(-not $Check.dependencyChecksRun){$lines.Add('Required tools could not be checked. Use Advanced > Check installation again.')}
    elseif($missing.Count){$lines.Add('Missing tools: '+($missing -join '; ')+'. Prepare them, then use Advanced > Check installation again.')}
    else{
        $lines.Add('Installed definitions: match. Required tools: available.')
        $lines.Add($(if(@($Check.helperChecks).Count){'Embedded command checks: passed.'}else{'No additional embedded checks apply to this selection.'}))
        if($NeedsRestart){$lines.Add('Exit CopyQ completely, then start it again. Rechecking definitions cannot confirm that its event listener is active.')}
    }
    $lines.Add('Not tested: actual copying and pasting, OCR accuracy, or external services. Try the selected features once.')
    [pscustomobject]@{Passed=[bool]$passed;Text=($lines -join "`r`n")}
}

function Get-CopyQWizardError([string] $Reason) {
    switch -Regex ($Reason) {
        'NO_COMMANDS_SELECTED' {return 'Choose at least one command to install or update, then click Review changes.'}
        'REVIEW_REQUIRED' {return 'This selection has not been reviewed. Click Review changes before installing.'}
        'COPYQ_REQUEST_FAILED|COPYQ_TIMEOUT|COPYQ_NOT_INSTALLED' {return 'Cannot reach CopyQ. Start CopyQ 16 as your normal Windows user, then try Review changes again.'}
        'COPYQ_16_REQUIRED' {return 'This package requires CopyQ 16.0.0. Check the installed CopyQ version before continuing.'}
        'PROTECTION_CONFLICT' {return 'Choose either Clipboard Router or Secret Protection (Standalone), not both. Show Frequent requires the router.'}
        'PROFILE_SHORTCUT_INVALID' {return "A shortcut is not valid. In Advanced, use a shortcut such as Ctrl+Shift+T, or '-' to clear it."}
        'SHORTCUT_CONFLICT' {return 'A selected shortcut is already owned by another command. Change it in Advanced or uncheck that command, then review again.'}
        'COMMAND_STATE_CHANGED|PACKAGE_CHANGED' {return 'Commands or package files changed after review. Review the changes again before trying to install.'}
        'NAME_CONFLICT|DUPLICATE_IDENTITY' {return 'A command name or identity conflicts with another installed command. Resolve the duplicate in CopyQ (F6), then review again.'}
        'UNKNOWN_COMMAND' {return 'The saved selection includes a command not present in this package. Choose commands from the list instead.'}
        default {return 'Setup stopped; success was not confirmed. Open Technical details for the reason. Review before retrying; Advanced contains command-only recovery.'}
    }
}

function Confirm-CopyQWizardChange($Owner, [string] $Message, [string] $Title) {
    [Windows.Forms.MessageBox]::Show($Owner,$Message,$Title,'YesNo','Warning') -eq 'Yes'
}

function New-CopyQSetupWizard([string] $Root, $InitialProfile) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()
    $package=Get-CopyQSetupPackage $Root
    $validateSelection={param($profile)
        Assert-CopyQSetupProfile $profile
        foreach ($id in $profile.commands) {
            if ($id -cnotin @($package.Catalog.id)) {throw 'UNKNOWN_COMMAND'}
        }
    }.GetNewClosure()
    if ($null -ne $InitialProfile) {& $validateSelection $InitialProfile}
    $form=[Windows.Forms.Form]::new()
    $form.Text='CopyQ Command Suite Setup';$form.Size=[Drawing.Size]::new(1120,840)
    $form.MinimumSize=[Drawing.Size]::new(1000,740);$form.StartPosition='CenterScreen'
    $form.Font=[Drawing.Font]::new('Segoe UI',10)
    $layout=[Windows.Forms.TableLayoutPanel]::new();$layout.Dock='Fill';$layout.RowCount=4;$layout.ColumnCount=1
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',76))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',60))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',70))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',40))
    $form.Controls.Add($layout)
    $intro=[Windows.Forms.Label]::new();$intro.Dock='Fill';$intro.Padding=[Windows.Forms.Padding]::new(12)
    $intro.Text="1 Choose what to change  >  2 Review changes  >  3 Install and check automatically`nCheck only commands you want to install or update. Unchecked commands stay installed and unchanged. Setup manages commands only; it does not download software or back up clipboard history."
    $layout.Controls.Add($intro,0,0)
    $grid=[Windows.Forms.DataGridView]::new();$grid.Dock='Fill';$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false
    $grid.RowHeadersVisible=$false;$grid.AutoSizeColumnsMode='Fill';$grid.SelectionMode='FullRowSelect'
    $grid.ColumnHeadersDefaultCellStyle.WrapMode='True';$grid.ColumnHeadersHeightSizeMode='AutoSize'
    $enabled=[Windows.Forms.DataGridViewCheckBoxColumn]::new();$enabled.Name='Install';$enabled.HeaderText='Install / update';$enabled.FillWeight=42;[void]$grid.Columns.Add($enabled)
    foreach ($entry in @(@('Command',160),@('Local shortcuts',65),@('Global shortcuts',65))) {
        $column=[Windows.Forms.DataGridViewTextBoxColumn]::new();$column.Name=$entry[0];$column.FillWeight=$entry[1]
        $column.ReadOnly=$entry[0] -eq 'Command';[void]$grid.Columns.Add($column)
    }
    foreach($entry in @(@('Installed',65),@('What it does',200))){
        $column=[Windows.Forms.DataGridViewTextBoxColumn]::new();$column.Name=$entry[0];$column.FillWeight=$entry[1];$column.ReadOnly=$true;[void]$grid.Columns.Add($column)
    }
    $grid.Columns[2].Visible=$false;$grid.Columns[3].Visible=$false
    $grid.Columns[2].HeaderText='Local override';$grid.Columns[3].HeaderText='Global override'
    $descriptions=@{
        'canonical.dispatcher'='Protect saved history, sort text into tabs, and index frequent copies.'
        'canonical.secret-protection'='Protect saved history only; an alternative to Clipboard Router.'
        'canonical.undoable-delete-listener'='Keep deleted items in Trash so Undo Delete can restore them.'
        'canonical.undo-delete'='Restore the latest deletion with Ctrl+Z; includes its trash listener.'
        'canonical.html-sanitizer'='Remove copied HTML text and background colours.'
        'canonical.markdown-render'='Display copied Markdown with formatting automatically.'
        'canonical.pygments-highlight'='Display selected source code with syntax colours and wrapping.'
        'canonical.ocr'='Copy English and Hebrew text from a selected clipboard image.'
        'canonical.translate-en'='Translate selected text using your optional Azure account.'
        'canonical.copy-json'='Export selected clipboard items as JSON.'
        'canonical.paste-json'='Import clipboard items from JSON.'
        'canonical.regex-search'='Search text across your CopyQ tabs.'
        'canonical.smart-title'='Change selected text to title case.'
        'canonical.toggle-case'='Switch selected text between upper and lower case.'
        'canonical.show-frequent'='Open the Frequent index; requires Clipboard Router.'
        'canonical.copy-and-search'='Search the web for selected text.'
        'moonlander.smart-title'='Use F13 for the Moonlander title-case workflow.'
        'moonlander.cycle-case'='Use F19 for the Moonlander case-cycle workflow.'
        'moonlander.hebrew-layout'='Use F22 to correct text typed with the wrong keyboard layout.'
    }
    foreach ($entry in $package.Catalog) {
        $index=$grid.Rows.Add($false,$entry.name,'','','Not checked',$descriptions[$entry.id]);$grid.Rows[$index].Tag=$entry.id
    }
    $grid.Columns['What it does'].DefaultCellStyle.WrapMode='True';$grid.AutoSizeRowsMode='AllCells'
    $layout.Controls.Add($grid,0,1)
    $buttons=[Windows.Forms.FlowLayoutPanel]::new();$buttons.Dock='Fill';$buttons.Padding=[Windows.Forms.Padding]::new(8);$buttons.AutoScroll=$true
    $layout.Controls.Add($buttons,0,2)
    $results=[Windows.Forms.TabControl]::new();$results.Dock='Fill'
    $summaryPage=[Windows.Forms.TabPage]::new('Summary');$summaryPage.Padding=[Windows.Forms.Padding]::new(8)
    $detailsPage=[Windows.Forms.TabPage]::new('Technical details');$detailsPage.Padding=[Windows.Forms.Padding]::new(8)
    [void]$results.TabPages.Add($summaryPage);[void]$results.TabPages.Add($detailsPage)
    $status=[Windows.Forms.TextBox]::new();$status.Name='summaryText';$status.Dock='Fill';$status.Multiline=$true;$status.ReadOnly=$true;$status.ScrollBars='Vertical'
    $status.BackColor=[Drawing.SystemColors]::Window
    $status.Text="No commands selected. Check what you want to change, then click Review changes.`r`nSelect installed commands is a convenience for updating your existing suite. Presets and shortcut editing are under Advanced."
    $details=[Windows.Forms.TextBox]::new();$details.Name='technicalDetails';$details.Dock='Fill';$details.Multiline=$true;$details.ReadOnly=$true;$details.ScrollBars='Both';$details.WordWrap=$false
    $summaryPage.Controls.Add($status);$detailsPage.Controls.Add($details);$layout.Controls.Add($results,0,3)
    $ui=@{Context=$null;Preview=$null;Review=$null;ReviewProfile=$null;LastReceipt=$null;LastProfile=$null;NeedsRestart=$false;PendingCheck=$false;Region='';PackageDigest=$package.Digest;Installed=@{};Loading=$false;Buttons=@{}}
    # Event callbacks outlive their calling PowerShell scope. Bind presenters
    # explicitly rather than relying on functions being globally visible.
    $ui.FormatReview=${function:Get-CopyQWizardReview};$ui.FormatVerification=${function:Get-CopyQWizardVerification}
    $ui.FormatError=${function:Get-CopyQWizardError};$ui.Confirm=${function:Confirm-CopyQWizardChange}
    $ui.InstallCommand=Get-Command Install-CopyQSetupSelection
    $ui.VerifyCommand=Get-Command Test-CopyQSetupInstallation
    $connect={if (-not $ui.Context) {$ui.Context=New-CopyQSetupContext -Root $Root};return $ui.Context}.GetNewClosure()
    $refreshInstalled={
        $snapshot=Get-CopyQSetupSnapshot (& $connect)
        $ui.Installed=@{};foreach($entry in $snapshot.inventory){if($entry.id -in @($package.Catalog.id)){$ui.Installed[$entry.id]=$entry}}
        $ui.Loading=$true
        try {foreach($row in $grid.Rows){
            $id=[string]$row.Tag;$row.Cells[4].Value=if($ui.Installed.ContainsKey($id)){'Installed'}else{'Not installed'}
            foreach($pair in @(@(2,'local'),@(3,'global'))){
                $current=if($ui.Installed.ContainsKey($id)){
                    $values=@($ui.Installed[$id].($pair[1]));if($values.Count){$values -join ';'}else{'none'}
                }else{'package default (new command)'}
                $row.Cells[$pair[0]].ToolTipText="Current: $current. Blank keeps it; '-' clears it. Enter a new shortcut only to change it."
            }
        }} finally {$ui.Loading=$false}
    }.GetNewClosure()
    $readProfile={
        [void]$grid.EndEdit()
        # Inherit from a fresh snapshot for every new review, never from the
        # values that happened to be installed when this window first opened.
        & $refreshInstalled
        $chosen=@($grid.Rows | Where-Object {$_.Cells[0].Value} | ForEach-Object {[string]$_.Tag})
        if(-not $chosen.Count){throw 'NO_COMMANDS_SELECTED'}
        $required=@()
        if('canonical.undo-delete' -in $chosen -or 'canonical.undoable-delete-listener' -in $chosen){$required+=@('canonical.undo-delete','canonical.undoable-delete-listener')}
        if('canonical.show-frequent' -in $chosen){$required+='canonical.dispatcher'}
        $ui.Loading=$true
        try{foreach($row in $grid.Rows){if([string]$row.Tag -in $required){$row.Cells[0].Value=$true}}}finally{$ui.Loading=$false}
        $ids=@();$overrides=@{}
        foreach ($row in $grid.Rows) {
            if (-not $row.Cells[0].Value) {continue}
            $id=[string]$row.Tag;$ids+=$id
            $local=[string]$row.Cells[2].Value;$global=[string]$row.Cells[3].Value
            if ($local -or $global -or $ui.Installed.ContainsKey($id)) {
                # Fill untouched side from package defaults, not an accidental empty override.
                $ini=($package.Catalog | Where-Object id -eq $id).ini
                $defaults=@{local=@();global=@()}
                foreach ($pair in @(@('local','Shortcut'),@('global','GlobalShortcut'))) {
                    $match=[regex]::Match($ini,'(?m)^'+$pair[1]+'=(.*)$')
                    if ($match.Success) {$defaults[$pair[0]]=@($match.Groups[1].Value.Trim() -split ',\s*')}
                }
                if($ui.Installed.ContainsKey($id)){$defaults=@{local=@($ui.Installed[$id].local);global=@($ui.Installed[$id].global)}}
                # Capture the entire conditional output as an array: PowerShell
                # otherwise unwraps one shortcut to a string and zero to null.
                if ($local) {$defaults.local=@(if ($local -ne '-') {$local.Split(';') | ForEach-Object {$_.Trim()}})}
                if ($global) {$defaults.global=@(if ($global -ne '-') {$global.Split(';') | ForEach-Object {$_.Trim()}})}
                $overrides[$id]=$defaults
            }
        }
        $profile=New-CopyQSetupProfile -Commands $ids -PackageDigest $ui.PackageDigest
        $profile.shortcuts=$overrides;$profile.azureRegion=$ui.Region
        Assert-CopyQSetupProfile $profile
        return $profile
    }.GetNewClosure()
    $showProfile={param($profile)
        & $validateSelection $profile
        $ui.Loading=$true
        try {
        foreach ($row in $grid.Rows) {
            $id=[string]$row.Tag;$row.Cells[0].Value=$id -in $profile.commands
            $row.Cells[2].Value='';$row.Cells[3].Value=''
            if ($profile.shortcuts.Contains($id)) {
                $o=$profile.shortcuts[$id];$row.Cells[2].Value=if($o.local.Count){$o.local -join ';'}else{'-'}
                $row.Cells[3].Value=if($o.global.Count){$o.global -join ';'}else{'-'}
            }
        }
        } finally {$ui.Loading=$false}
        $ui.Region=$profile.azureRegion;$ui.PackageDigest=$profile.packageDigest;$ui.Preview=$null
    }.GetNewClosure()
    $actions=[ordered]@{}
    $actions['Uncheck all']={
        [void]$grid.EndEdit()
        foreach ($row in $grid.Rows) {$row.Cells[0].Value=$false}
        & $ui.Invalidate
        $status.Text='All commands unchecked. Shortcut edits are retained. Check only the commands you want to install or update; unchecked installed commands stay untouched.'
    }.GetNewClosure()
    $actions['Essentials']={& $showProfile (New-CopyQSetupProfile);& $ui.Invalidate}.GetNewClosure()
    $actions['All general tools']={& $showProfile (New-CopyQSetupProfile -Commands @($package.Catalog.id | Where-Object {$_ -like 'canonical.*' -and $_ -ne 'canonical.secret-protection'}));& $ui.Invalidate}.GetNewClosure()
    $actions['Protection only']={& $showProfile (New-CopyQSetupProfile -Commands @('canonical.secret-protection'));& $ui.Invalidate}.GetNewClosure()
    $actions['Load profile']={
        $dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Filter='Setup profile (*.json)|*.json'
        try {if($dialog.ShowDialog() -eq 'OK'){& $showProfile (Read-CopyQSetupProfile $dialog.FileName);& $ui.Invalidate;$status.Text='Profile loaded. Review changes before installing.'}}finally{$dialog.Dispose()}
    }.GetNewClosure()
    $actions['Save profile']={
        $profile=& $readProfile;$profile.packageDigest=$package.Digest
        $dialog=[Windows.Forms.SaveFileDialog]::new();$dialog.Filter='Setup profile (*.json)|*.json';$dialog.FileName='copyq-setup-profile.json'
        try{if($dialog.ShowDialog() -eq 'OK'){Save-CopyQSetupProfile $profile $dialog.FileName;$status.Text='Nonsecret profile saved. This stores selections, not command bodies or clipboard history.'}}finally{$dialog.Dispose()}
    }.GetNewClosure()
    $actions['Select installed commands']={
        & $refreshInstalled
        $ids=@($grid.Rows | Where-Object {$ui.Installed.ContainsKey([string]$_.Tag)} | ForEach-Object {[string]$_.Tag})
        if($ids.Count){& $showProfile (New-CopyQSetupProfile -Commands $ids);& $ui.Invalidate;$status.Text='Your installed suite commands are selected for update. Existing shortcuts are retained. Uncheck anything you do not want to update, then review changes.'}
        else{$status.Text='No suite commands were found. Check individual commands or choose a preset under Advanced.'}
    }.GetNewClosure()
    $actions['Review changes']={
        $ui.Preview=$null;$ui.Review=$null
        $profile=& $readProfile;$preview=Get-CopyQSetupPreview (& $connect) $profile;$ui.Preview=$preview
        $ui.Review=& $ui.FormatReview $preview $package.Catalog;$ui.ReviewProfile=$profile
        $status.Text=$ui.Review.Text
        $details.Text=($preview | Select-Object added,updated,unchanged,replacedProtection,preserved,selected,needsRestart,missingDependencies | ConvertTo-Json -Depth 5)
        if($profile.packageDigest -and $profile.packageDigest -ne $package.Digest){$status.AppendText("`r`nProfile came from a different package version. The listed changes use this downloaded package.")}
    }.GetNewClosure()
    $actions['Install / update']={
        [void]$grid.EndEdit()
        if($null -eq $ui.Preview -or -not $ui.Review.Ready -or -not $ui.Review.HasChanges){throw 'REVIEW_REQUIRED'}
        $preview=$ui.Preview;$profile=$ui.ReviewProfile;$context=& $connect
        if(-not (& $ui.Confirm $form ($ui.Review.Text+"`r`n`r`nApply these reviewed changes?") 'Confirm command changes')){return}
        $ui.PendingCheck=$false
        $result=& $ui.InstallCommand $context $preview;$ui.LastReceipt=$result.receipt
        $ui.LastProfile=$profile;$ui.NeedsRestart=$preview.needsRestart -and $result.result -eq 'installed';$ui.PendingCheck=$true
        $ui.Preview=$null;$ui.Review=$null;$ui.ReviewProfile=$null
        $verification=& $ui.VerifyCommand $context $profile
        & $refreshInstalled
        $checked=& $ui.FormatVerification $verification $ui.NeedsRestart;$ui.PendingCheck=-not $checked.Passed
        $status.Text=$checked.Text
        if($result.receipt){$status.AppendText("`r`nA private command-only backup was saved. Advanced > Restore commands can undo this installation.")}
        $details.Text=@{installation=$result;verification=$verification} | ConvertTo-Json -Depth 7
    }.GetNewClosure()
    $actions['Check installation again']={
        $checkingPending=$ui.PendingCheck -and $null -ne $ui.LastProfile
        $profile=if($checkingPending){$ui.LastProfile}else{& $readProfile}
        $verification=& $ui.VerifyCommand (& $connect) $profile
        $checked=& $ui.FormatVerification $verification $ui.NeedsRestart
        if($checkingPending){$ui.PendingCheck=-not $checked.Passed}
        $status.Text=$checked.Text;$details.Text=$verification | ConvertTo-Json -Depth 6
    }.GetNewClosure()
    $actions['Restore commands']={
        $dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Filter='Setup receipt (receipt.json)|receipt.json';$dialog.InitialDirectory=Join-Path $env:LOCALAPPDATA 'CopyQCommandSuite/setup'
        try{if($dialog.ShowDialog() -eq 'OK'){
            if(& $ui.Confirm $form 'Restore the previous command set? Later command edits cause a safe refusal. No clipboard data or credentials are restored.' 'Restore'){
                $restored=Restore-CopyQSetupCommands (& $connect) $dialog.FileName
                $ui.PendingCheck=$false;$ui.NeedsRestart=$false;& $ui.Invalidate
                & $refreshInstalled
                $status.Text='Previous command definitions restored. Restart CopyQ if script commands were restored.'
                $details.Text=$restored | ConvertTo-Json
            }
        }}finally{$dialog.Dispose()}
    }.GetNewClosure()
    $actions['Configure Azure']={
        $reuse=Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'CopyQTranslation/azure-key.dpapi') -PathType Leaf
        $message=if($reuse){'Install the translation helper using your EXISTING encrypted key? The key will not be changed. Only the region may be requested in the console.'}else{'Install the translation helper and enter your Azure key and region securely in the console?'}
        if([Windows.Forms.MessageBox]::Show($form,$message+' Command rollback does not revert this separate configuration.','Azure configuration','YesNo','Question') -ne 'Yes'){return}
        $form.Hide()
        try {& (Join-Path $Root 'scripts/Install-CopyQTranslation.ps1') -Region $ui.Region -ReuseExistingCredential:$reuse | Out-Null;$status.Text='Azure helper configured. Existing key retained when available. Run Translate to English on disposable text to verify the service.'} finally {$form.Show()}
    }.GetNewClosure()
    $actions['Dependency help']={Start-Process (Join-Path $Root 'docs/SETUP.md') -WindowStyle Hidden}.GetNewClosure()
    $mainActions=@('Uncheck all','Select installed commands','Review changes','Install / update')
    $orderedActions=@($mainActions)+@($actions.Keys | Where-Object {$_ -notin $mainActions})
    foreach($label in $orderedActions) {
        $entry=[pscustomobject]@{Key=$label;Value=$actions[$label]}
        $button=[Windows.Forms.Button]::new();$button.Text=$entry.Key;$button.AutoSize=$true;$button.Padding=[Windows.Forms.Padding]::new(4)
        $button.Visible=$entry.Key -in $mainActions
        if($entry.Key -eq 'Review changes'){$button.Name='reviewButton'}
        if($entry.Key -eq 'Install / update'){$button.Name='applyButton'}
        $ui.Buttons[$entry.Key]=$button
        $action=$entry.Value
        $button.Add_Click({
            $form.UseWaitCursor=$true;$buttons.Enabled=$false;$grid.Enabled=$false
            try{& $action}catch{
                $ui.Preview=$null;$ui.Review=$null
                $details.Text=$_.Exception.Message;$status.Text=& $ui.FormatError $_.Exception.Message
                if($ui.PendingCheck){$status.Text="Commands were installed, but checking did not finish.`r`n"+$status.Text+"`r`nUse Advanced > Check installation again; do not reinstall just to retry checking."}
            }finally{$buttons.Enabled=$true;$grid.Enabled=$true;$form.UseWaitCursor=$false;$results.SelectedTab=$summaryPage;& $ui.UpdateButtons}
        }.GetNewClosure())
        $buttons.Controls.Add($button)
    }
    $advanced=[Windows.Forms.CheckBox]::new();$advanced.Text='Advanced';$advanced.AutoSize=$true;$advanced.Padding=[Windows.Forms.Padding]::new(8);$advanced.Name='advancedOptions'
    $advanced.Add_CheckedChanged({
        foreach($label in $ui.Buttons.Keys){if($label -notin $mainActions){$ui.Buttons[$label].Visible=$advanced.Checked}}
        $grid.Columns[2].Visible=$advanced.Checked;$grid.Columns[3].Visible=$advanced.Checked
        $layout.RowStyles[2].Height=if($advanced.Checked){160}else{70}
        if($advanced.Checked){
            $status.AppendText("`r`nShortcut overrides: leave blank to keep the current shortcut (hover for its value); '-' clears it. Enter a shortcut only to change it; separate multiple shortcuts with semicolons.")
        }
    }.GetNewClosure());$buttons.Controls.Add($advanced);$buttons.Controls.SetChildIndex($advanced,$mainActions.Count)
    $ui.UpdateButtons={
        $selected=@($grid.Rows | Where-Object {$_.Cells[0].Value}).Count
        $ui.Buttons['Review changes'].Enabled=$selected -gt 0
        $ui.Buttons['Install / update'].Enabled=$null -ne $ui.Preview -and $ui.Review.Ready -and $ui.Review.HasChanges
    }.GetNewClosure()
    $ui.Invalidate={
        $ui.Preview=$null;$ui.Review=$null;$ui.ReviewProfile=$null;$details.Clear()
        $status.Text=if(@($grid.Rows | Where-Object {$_.Cells[0].Value}).Count){'Selection changed. Click Review changes before installing. Unchecked commands stay unchanged.'}else{'No commands selected. Check what you want to install or update, then click Review changes.'}
        & $ui.UpdateButtons
    }.GetNewClosure()
    $grid.Add_CurrentCellDirtyStateChanged({if($grid.IsCurrentCellDirty -and $grid.CurrentCell.ColumnIndex -eq 0){[void]$grid.CommitEdit([Windows.Forms.DataGridViewDataErrorContexts]::Commit)}}.GetNewClosure())
    $grid.Add_CellValueChanged({param($sender,$eventArgs) if(-not $ui.Loading -and $eventArgs.RowIndex -ge 0 -and $eventArgs.ColumnIndex -in @(0,2,3)){& $ui.Invalidate}}.GetNewClosure())
    $form.Add_Shown({
        try{& $refreshInstalled}catch{$details.Text=$_.Exception.Message;$status.Text=& $ui.FormatError $_.Exception.Message}
    }.GetNewClosure())
    if($null -ne $InitialProfile){& $showProfile $InitialProfile}
    & $ui.UpdateButtons
    [pscustomobject]@{Form=$form;Grid=$grid;Actions=@($actions.Keys)}
}
