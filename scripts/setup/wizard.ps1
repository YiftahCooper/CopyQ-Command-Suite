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
    if ($null -eq $InitialProfile) {$InitialProfile=New-CopyQSetupProfile}
    & $validateSelection $InitialProfile
    $form=[Windows.Forms.Form]::new()
    $form.Text='CopyQ Command Suite Setup';$form.Size=[Drawing.Size]::new(1000,760)
    $form.MinimumSize=[Drawing.Size]::new(900,680);$form.StartPosition='CenterScreen'
    $form.Font=[Drawing.Font]::new('Segoe UI',10)
    $layout=[Windows.Forms.TableLayoutPanel]::new();$layout.Dock='Fill';$layout.RowCount=4;$layout.ColumnCount=1
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',76))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',60))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',110))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',40))
    $form.Controls.Add($layout)
    $intro=[Windows.Forms.Label]::new();$intro.Dock='Fill';$intro.Padding=[Windows.Forms.Padding]::new(12)
    $intro.Text="Choose commands, preview, then install. Start CopyQ 16.0.0 as your normal user first.`nUnchecked existing commands stay installed. Undo installs its partner automatically. No clipboard-history backup or software downloads."
    $layout.Controls.Add($intro,0,0)
    $grid=[Windows.Forms.DataGridView]::new();$grid.Dock='Fill';$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false
    $grid.RowHeadersVisible=$false;$grid.AutoSizeColumnsMode='Fill';$grid.SelectionMode='FullRowSelect'
    $enabled=[Windows.Forms.DataGridViewCheckBoxColumn]::new();$enabled.Name='Install';$enabled.FillWeight=18;[void]$grid.Columns.Add($enabled)
    foreach ($entry in @(@('Command',160),@('Local shortcuts',65),@('Global shortcuts',65))) {
        $column=[Windows.Forms.DataGridViewTextBoxColumn]::new();$column.Name=$entry[0];$column.FillWeight=$entry[1]
        $column.ReadOnly=$entry[0] -eq 'Command';[void]$grid.Columns.Add($column)
    }
    foreach ($entry in $package.Catalog) {
        $index=$grid.Rows.Add($false,$entry.name,'','');$grid.Rows[$index].Tag=$entry.id
    }
    $layout.Controls.Add($grid,0,1)
    $buttons=[Windows.Forms.FlowLayoutPanel]::new();$buttons.Dock='Fill';$buttons.Padding=[Windows.Forms.Padding]::new(8)
    $layout.Controls.Add($buttons,0,2)
    $status=[Windows.Forms.TextBox]::new();$status.Dock='Fill';$status.Multiline=$true;$status.ReadOnly=$true;$status.ScrollBars='Vertical'
    $status.Text="Start with Essentials or load a profile. Blank shortcut cells keep the packaged default; enter '-' to clear. Separate multiple shortcuts with semicolons.`r`nInstall updates selected suite commands, including any edits you made to them. Preview lists these updates. Unrelated commands are preserved."
    $layout.Controls.Add($status,0,3)
    $ui=@{Context=$null;Preview=$null;LastReceipt=$null;Region='';Overrides=@{};PackageDigest=$package.Digest}
    $readProfile={
        [void]$grid.EndEdit()
        $ids=@();$overrides=@{}
        foreach ($row in $grid.Rows) {
            if (-not $row.Cells[0].Value) {continue}
            $id=[string]$row.Tag;$ids+=$id
            $local=[string]$row.Cells[2].Value;$global=[string]$row.Cells[3].Value
            if ($local -or $global) {
                # Fill untouched side from package defaults, not an accidental empty override.
                $ini=($package.Catalog | Where-Object id -eq $id).ini
                $defaults=@{local=@();global=@()}
                foreach ($pair in @(@('local','Shortcut'),@('global','GlobalShortcut'))) {
                    $match=[regex]::Match($ini,'(?m)^'+$pair[1]+'=(.*)$')
                    if ($match.Success) {$defaults[$pair[0]]=@($match.Groups[1].Value.Trim() -split ',\s*')}
                }
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
        foreach ($row in $grid.Rows) {
            $id=[string]$row.Tag;$row.Cells[0].Value=$id -in $profile.commands
            $row.Cells[2].Value='';$row.Cells[3].Value=''
            if ($profile.shortcuts.Contains($id)) {
                $o=$profile.shortcuts[$id];$row.Cells[2].Value=if($o.local.Count){$o.local -join ';'}else{'-'}
                $row.Cells[3].Value=if($o.global.Count){$o.global -join ';'}else{'-'}
            }
        }
        $ui.Region=$profile.azureRegion;$ui.PackageDigest=$profile.packageDigest;$ui.Preview=$null
    }.GetNewClosure()
    $connect={if (-not $ui.Context) {$ui.Context=New-CopyQSetupContext -Root $Root};return $ui.Context}.GetNewClosure()
    $actions=[ordered]@{}
    $actions['Essentials']={& $showProfile (New-CopyQSetupProfile)}.GetNewClosure()
    $actions['All general tools']={& $showProfile (New-CopyQSetupProfile -Commands @($package.Catalog.id | Where-Object {$_ -like 'canonical.*' -and $_ -ne 'canonical.secret-protection'}))}.GetNewClosure()
    $actions['Protection only']={& $showProfile (New-CopyQSetupProfile -Commands @('canonical.secret-protection'))}.GetNewClosure()
    $actions['Load profile']={
        $dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Filter='Setup profile (*.json)|*.json'
        try {if($dialog.ShowDialog() -eq 'OK'){& $showProfile (Read-CopyQSetupProfile $dialog.FileName);$status.Text='Profile loaded. Preview before installing.'}}finally{$dialog.Dispose()}
    }.GetNewClosure()
    $actions['Save profile']={
        $profile=& $readProfile;$profile.packageDigest=$package.Digest
        $dialog=[Windows.Forms.SaveFileDialog]::new();$dialog.Filter='Setup profile (*.json)|*.json';$dialog.FileName='copyq-setup-profile.json'
        try{if($dialog.ShowDialog() -eq 'OK'){Save-CopyQSetupProfile $profile $dialog.FileName;$status.Text='Nonsecret profile saved. This stores selections, not command bodies or clipboard history.'}}finally{$dialog.Dispose()}
    }.GetNewClosure()
    $actions['Read installed selection']={& $showProfile (Export-CopyQSetupProfile (& $connect));$status.Text='Installed suite selection and shortcuts loaded. Save profile to keep these choices. Community commands are not included in this profile.'}.GetNewClosure()
    $actions['Preview changes']={
        $profile=& $readProfile;$preview=Get-CopyQSetupPreview (& $connect) $profile;$ui.Preview=$preview
        $status.Text=($preview | Select-Object added,updated,unchanged,replacedProtection,preserved,selected,needsRestart,missingDependencies | ConvertTo-Json -Depth 4)
        if($profile.packageDigest -and $profile.packageDigest -ne $package.Digest){$status.AppendText("`r`nProfile came from a different package version. The listed changes use this downloaded package.")}
    }.GetNewClosure()
    $actions['Install selected']={
        $profile=& $readProfile;$context=& $connect;$preview=Get-CopyQSetupPreview $context $profile
        if ($preview.missingDependencies.Count) {throw ('DEPENDENCIES_MISSING: '+($preview.missingDependencies -join '; ')+'. Prepare these dependencies or deselect their commands, then preview again.')}
        $summary="Add: $($preview.added.Count) | Replace/update: $($preview.updated.Count) | Replace protection: $($preview.replacedProtection.Count)`r`nSelected suite command edits will be replaced. Unrelated commands and app preferences stay intact.`r`nA private command-only backup will be saved. Proceed?"
        if([Windows.Forms.MessageBox]::Show($form,$summary,'Confirm command installation','YesNo','Warning') -ne 'Yes'){return}
        $result=Install-CopyQSetupSelection $context $preview;$ui.LastReceipt=$result.receipt
        $verification=Test-CopyQSetupInstallation $context $profile
        $status.Text=($result | ConvertTo-Json)+"`r`n"+($verification | ConvertTo-Json -Depth 6)+"`r`nIf an undo listener was installed or updated, exit CopyQ completely and start it again. Then click Verify. External services and real paste are not tested automatically."
    }.GetNewClosure()
    $actions['Verify']={$status.Text=Test-CopyQSetupInstallation (& $connect) (& $readProfile) | ConvertTo-Json -Depth 6}.GetNewClosure()
    $actions['Restore commands']={
        $dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Filter='Setup receipt (receipt.json)|receipt.json';$dialog.InitialDirectory=Join-Path $env:LOCALAPPDATA 'CopyQCommandSuite/setup'
        try{if($dialog.ShowDialog() -eq 'OK'){
            if([Windows.Forms.MessageBox]::Show($form,'Restore the previous command set? Later command edits cause a safe refusal. No clipboard data or credentials are restored.','Restore','YesNo','Warning') -eq 'Yes'){
                $status.Text=Restore-CopyQSetupCommands (& $connect) $dialog.FileName | ConvertTo-Json
                $status.AppendText("`r`nRestart CopyQ after restoring script commands.")
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
    foreach($entry in $actions.GetEnumerator()) {
        $button=[Windows.Forms.Button]::new();$button.Text=$entry.Key;$button.AutoSize=$true;$button.Padding=[Windows.Forms.Padding]::new(4)
        $action=$entry.Value
        $button.Add_Click({
            $form.UseWaitCursor=$true;$buttons.Enabled=$false
            try{& $action}catch{$status.Text=$_.Exception.Message}finally{$buttons.Enabled=$true;$form.UseWaitCursor=$false}
        }.GetNewClosure())
        $buttons.Controls.Add($button)
    }
    & $showProfile $InitialProfile
    [pscustomobject]@{Form=$form;Grid=$grid;Actions=@($actions.Keys)}
}
