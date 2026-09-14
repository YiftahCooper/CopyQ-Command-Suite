$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\CopyQ.Setup.psm1') -Force

Describe 'Setup profiles and package boundary' {
    It 'prepares translation using an existing encrypted credential without changing its bytes' {
        $credential=Join-Path $TestDrive 'existing.dpapi'
        [IO.File]::WriteAllText($credential,'synthetic encrypted fixture - never decrypted')
        $hash=(Get-FileHash $credential).Hash
        $destination=Join-Path $TestDrive 'translation'
        $config=Join-Path $TestDrive 'translator.json'
        & (Join-Path $PSScriptRoot '../scripts/Install-CopyQTranslation.ps1') -DestinationRoot $destination -CredentialPath $credential -ConfigurationPath $config -Region germanywestcentral -ReuseExistingCredential | Out-Null
        (Get-FileHash $credential).Hash | Should Be $hash
        (Get-Content $config -Raw | ConvertFrom-Json).region | Should Be 'germanywestcentral'
        (Test-Path (Join-Path $destination 'CopyQ.Translation.psm1')) | Should Be $true
        (Test-Path (Join-Path $destination 'Invoke-CopyQAzureTranslation.ps1')) | Should Be $true
    }
    It 'reports missing portable translation files and region before installation' {
        $context=New-CopyQSetupContext -Root (Split-Path -Parent $PSScriptRoot) -StateRoot (Join-Path $TestDrive 'state')
        $result=Get-CopyQSetupDependencyStatus $context @('canonical.translate-en') -LocalAppData $TestDrive
        $result.ready | Should Be $false
        ($result.missingDependencies -join ';') | Should Match 'Azure'
        (Get-CopyQSetupDependencyStatus $context @('canonical.smart-title') -LocalAppData $TestDrive).ready | Should Be $true
    }
    It 'round trips only nonsecret profile choices and rejects unknown fields' {
        $path = Join-Path $TestDrive 'profile.json'
        $profile = New-CopyQSetupProfile -Commands @('canonical.dispatcher')
        Save-CopyQSetupProfile -Profile $profile -Path $path
        (Read-CopyQSetupProfile -Path $path).commands | Should Be @('canonical.dispatcher')
        $profile['key'] = 'synthetic-not-a-real-key'
        { Save-CopyQSetupProfile -Profile $profile -Path $path } | Should Throw 'PROFILE_UNKNOWN_FIELD'
    }
    It 'rejects traversal and rooted package filenames' {
        { Resolve-CopyQPackagePath -Root $TestDrive -Relative '../escape.ini' } | Should Throw 'PACKAGE_PATH_INVALID'
        { Resolve-CopyQPackagePath -Root $TestDrive -Relative 'C:/escape.ini' } | Should Throw 'PACKAGE_PATH_INVALID'
    }
    It 'reads all nineteen available command exports without requiring Node' {
        $package = Get-CopyQSetupPackage -Root (Split-Path -Parent $PSScriptRoot)
        $package.Catalog.Count | Should Be 19
        $package.Digest | Should Match '^[a-f0-9]{64}$'
        ($package.Catalog | Where-Object id -eq 'canonical.secret-protection').ini | Should Match 'InternalId=canonical.secret-protection'
    }
}

Describe 'Setup native installation and command-only recovery' {
    BeforeAll {
        $script:setupRoot = Split-Path -Parent $PSScriptRoot
        $script:setupSession = 'cqst-' + [guid]::NewGuid().ToString('N').Substring(0,8)
        $script:oldSettings = $env:COPYQ_SETTINGS_PATH; $script:oldItems = $env:COPYQ_ITEM_DATA_PATH
        $env:COPYQ_SETTINGS_PATH = Join-Path $TestDrive 'settings'; $env:COPYQ_ITEM_DATA_PATH = Join-Path $TestDrive 'items'
        $script:setupContext = New-CopyQSetupContext -Root $setupRoot -Session $setupSession -StateRoot (Join-Path $TestDrive 'state')
        $script:setupServer = Start-Process $setupContext.Executable -ArgumentList @('-s',$setupSession) -WindowStyle Hidden -PassThru
        for ($attempt=0; $attempt -lt 40; $attempt++) {
            Start-Sleep -Milliseconds 100
            try { Invoke-CopyQSetupProcess $setupContext @('tab') | Out-Null; break } catch { if ($attempt -eq 39) { throw } }
        }
        Invoke-CopyQSetupProcess $setupContext @('eval',"setCommands([{name:'Unrelated',cmd:'copyq: 1',re:/^keep$/}]);tab('Existing');insert(0,'keep item');'READY'") | Out-Null
    }
    AfterAll {
        if ($script:setupContext) { Invoke-CopyQSetupProcess $setupContext @('exit') | Out-Null }
        if ($script:setupServer) { [void]$setupServer.WaitForExit(5000) }
        $env:COPYQ_SETTINGS_PATH=$script:oldSettings; $env:COPYQ_ITEM_DATA_PATH=$script:oldItems
    }
    It 'installs selection, reads it back, repeats safely and restores exact native commands' {
        $profile = New-CopyQSetupProfile -Commands @('canonical.dispatcher','canonical.undo-delete')
        $before = Get-CopyQSetupSnapshot $setupContext
        $preview = Get-CopyQSetupPreview $setupContext $profile
        $preview.added.Count | Should Be 3
        $installed = Install-CopyQSetupSelection $setupContext $preview
        $installed.result | Should Be 'installed'
        $after = Get-CopyQSetupSnapshot $setupContext
        $after.inventory.Count | Should Be ($before.inventory.Count + 3)
        $verification=Test-CopyQSetupInstallation $setupContext $profile
        $verification.definitionsVerified | Should Be $true
        $verification.helpersPassed | Should Be $true
        $verification.helperChecks.Count | Should Be 1
        (Export-CopyQSetupProfile $setupContext).commands.Count | Should Be 3
        $repeat = Get-CopyQSetupPreview $setupContext $profile
        (Install-CopyQSetupSelection $setupContext $repeat).result | Should Be 'unchanged'
        (Restore-CopyQSetupCommands $setupContext $installed.receipt).result | Should Be 'restored'
        (Get-CopyQSetupSnapshot $setupContext).native | Should Be $before.native
        Invoke-CopyQSetupProcess $setupContext @('eval',"tab('Existing');str(read(0))") | Should Be 'keep item'
    }
    It 'installs all fourteen nontranslation tools without Azure and preserves deferred commands exactly' {
        $original=Get-CopyQSetupSnapshot $setupContext
        $previousLocal=$env:LOCALAPPDATA
        $installed=$null
        try {
            Invoke-CopyQSetupProcess $setupContext @('eval',"var c=commands();c.push({internalId:'canonical.translate-en',name:'Translate to English',cmd:'copyq: // Existing private helper',re:/^UNCHANGED$/,enable:true});c.push({name:'Moonlander: Smart Title Case',cmd:'copyq: // Existing companion',globalShortcuts:['F13'],isGlobalShortcut:true});setCommands(c)") | Out-Null
            $baseline=Get-CopyQSetupSnapshot $setupContext
            $readDeferred="str(exportCommands(commands().filter(function(c){return c.internalId==='canonical.translate-en'||!/^canonical\./.test(c.internalId||'');})))"
            $deferredBefore=Invoke-CopyQSetupProcess $setupContext @('eval',$readDeferred)
            $env:LOCALAPPDATA=Join-Path $TestDrive 'azure-not-configured'
            $ids=@($setupContext.Package.Catalog.id | Where-Object {$_ -like 'canonical.*' -and $_ -notin @('canonical.translate-en','canonical.secret-protection')})
            $ids.Count | Should Be 14
            $profile=New-CopyQSetupProfile -Commands $ids
            $preview=Get-CopyQSetupPreview $setupContext $profile
            $preview.missingDependencies.Count | Should Be 0
            $preview.preserved | Should Be $baseline.inventory.Count
            $installed=Install-CopyQSetupSelection $setupContext $preview
            $installed.result | Should Be 'installed'
            $verified=Test-CopyQSetupInstallation $setupContext $profile
            $verified.definitionsVerified | Should Be $true
            $verified.helpersPassed | Should Be $true
            $deferred=Invoke-CopyQSetupProcess $setupContext @('eval',$readDeferred)
            ($deferred -ceq $deferredBefore) | Should Be $true
            (Get-CopyQSetupPreview $setupContext $profile).unchanged.Count | Should Be 14
        } finally {
            $env:LOCALAPPDATA=$previousLocal
            if($installed){Restore-CopyQSetupCommands $setupContext $installed.receipt | Out-Null}
            $encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($original.native))
            Invoke-CopyQSetupProcess $setupContext @('eval',"setCommands(importCommands(str(fromBase64('$encoded'))))") | Out-Null
        }
    }
    It 'refuses installation before mutation when a selected dependency is missing' {
        $previousLocal=$env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA=Join-Path $TestDrive 'not-configured'
            $profile=New-CopyQSetupProfile -Commands @('canonical.translate-en')
            $preview=Get-CopyQSetupPreview $setupContext $profile
            $preview.missingDependencies.Count | Should BeGreaterThan 0
            $before=Get-CopyQSetupSnapshot $setupContext
            {Install-CopyQSetupSelection $setupContext $preview} | Should Throw 'DEPENDENCIES_MISSING'
            ((Get-CopyQSetupSnapshot $setupContext).native -ceq $before.native) | Should Be $true
        } finally {$env:LOCALAPPDATA=$previousLocal}
    }
    It 'recovers an interrupted prepared receipt and detects modified backup bytes' {
        $profile=New-CopyQSetupProfile -Commands @('canonical.html-sanitizer')
        $before=Get-CopyQSetupSnapshot $setupContext
        $installed=Install-CopyQSetupSelection $setupContext (Get-CopyQSetupPreview $setupContext $profile)
        $receipt=Get-Content $installed.receipt -Raw | ConvertFrom-Json -AsHashtable
        $receipt.result='prepared'
        Write-CopyQSetupReceipt $receipt $installed.receipt
        (Restore-CopyQSetupCommands $setupContext $installed.receipt).result | Should Be 'restored'
        (Get-CopyQSetupSnapshot $setupContext).native | Should Be $before.native
        $backup=Join-Path (Split-Path -Parent $installed.receipt) 'before.ini'
        [IO.File]::AppendAllText($backup,'changed')
        {Restore-CopyQSetupCommands $setupContext $installed.receipt} | Should Throw 'RESTORE_BACKUP_CHANGED'
    }
    It 'preserves intentional carriage returns and native regular expressions in unrelated commands' {
        $original=Invoke-CopyQSetupProcess $setupContext @('eval','var c=commands();c.push({name:"CR fixture",cmd:"copyq: // first\rsecond",re:/^CaseSensitive$/});setCommands(c);JSON.stringify(commands().filter(function(x){return x.name==="CR fixture";})[0].cmd)')
        $profile=New-CopyQSetupProfile -Commands @('canonical.html-sanitizer')
        $installed=Install-CopyQSetupSelection $setupContext (Get-CopyQSetupPreview $setupContext $profile)
        $actual=Invoke-CopyQSetupProcess $setupContext @('eval','JSON.stringify(commands().filter(function(x){return x.name==="CR fixture";})[0].cmd)')
        ($actual -ceq $original) | Should Be $true
        Invoke-CopyQSetupProcess $setupContext @('eval','var c=commands().filter(function(x){return x.name==="CR fixture";})[0];c.re.test("CaseSensitive") && !c.re.test("casesensitive")') | Should Be 'true'
        (Restore-CopyQSetupCommands $setupContext $installed.receipt).result | Should Be 'restored'
    }
    It 'rejects preview drift and refuses rollback over later command edits' {
        $profile = New-CopyQSetupProfile -Commands @('canonical.smart-title')
        $preview = Get-CopyQSetupPreview $setupContext $profile
        Invoke-CopyQSetupProcess $setupContext @('eval',"var c=commands();c.push({name:'Later edit',cmd:'copyq: 2'});setCommands(c)") | Out-Null
        { Install-CopyQSetupSelection $setupContext $preview } | Should Throw 'COMMAND_STATE_CHANGED'
        $installed = Install-CopyQSetupSelection $setupContext (Get-CopyQSetupPreview $setupContext $profile)
        Invoke-CopyQSetupProcess $setupContext @('eval',"var c=commands();c.push({name:'Another edit',cmd:'copyq: 3'});setCommands(c)") | Out-Null
        { Restore-CopyQSetupCommands $setupContext $installed.receipt } | Should Throw 'RESTORE_STATE_CHANGED'
    }
    It 'restores the recorded baseline after an injected readback acceptance failure' {
        $profile=New-CopyQSetupProfile -Commands @('canonical.toggle-case')
        $preview=Get-CopyQSetupPreview $setupContext $profile
        $prior=@(Get-ChildItem $setupContext.StateRoot -Directory | ForEach-Object FullName)
        & (Get-Module CopyQ.Setup) {$script:setupReadbackCalls=0}
        Mock Get-CopyQSetupSnapshot -ModuleName CopyQ.Setup {
            $script:setupReadbackCalls++
            $snapshot=Invoke-CopyQSetupBridge $Context @{action='snapshot'}
            if ($script:setupReadbackCalls -eq 2) {$snapshot.native+='injected acceptance failure'}
            return $snapshot
        }
        {Install-CopyQSetupSelection $setupContext $preview} | Should Throw 'INSTALLED_COMMAND_MISMATCH'
        $new=@(Get-ChildItem $setupContext.StateRoot -Directory | Where-Object {$_.FullName -notin $prior})
        $new.Count | Should Be 1
        $receipt=Get-Content (Join-Path $new[0].FullName 'receipt.json') -Raw | ConvertFrom-Json
        $receipt.result | Should Be 'failed'
        $receipt.rollback | Should Be 'restored'
        ((Get-CopyQSetupSnapshot $setupContext).native -ceq $preview.before) | Should Be $true
    }
    It 'does not execute helper code from an edited installed command during verification' {
        $profile=New-CopyQSetupProfile -Commands @('canonical.smart-title')
        Install-CopyQSetupSelection $setupContext (Get-CopyQSetupPreview $setupContext $profile) | Out-Null
        $probe='settings("setup_probe","");var c=commands();for(var i=0;i<c.length;i++)if(c[i].internalId==="canonical.smart-title")c[i].cmd=c[i].cmd.replace("copyq:","copyq: settings(''setup_probe'',''RAN'');");setCommands(c)'
        Invoke-CopyQSetupProcess $setupContext @('eval',$probe) | Out-Null
        $result=Test-CopyQSetupInstallation $setupContext $profile
        $result.definitionsVerified | Should Be $false
        Invoke-CopyQSetupProcess $setupContext @('eval',"str(settings('setup_probe'))") | Should Be ''
    }
    It 'detects case-only edits, installs their repair and refuses case-only rollback drift' {
        $profile=New-CopyQSetupProfile -Commands @('canonical.smart-title')
        Install-CopyQSetupSelection $setupContext (Get-CopyQSetupPreview $setupContext $profile) | Out-Null
        Invoke-CopyQSetupProcess $setupContext @('eval','var c=commands();for(var i=0;i<c.length;i++)if(c[i].internalId==="canonical.smart-title")c[i].name=c[i].name.toLowerCase();setCommands(c)') | Out-Null
        (Test-CopyQSetupInstallation $setupContext $profile).definitionsVerified | Should Be $false
        $installed=Install-CopyQSetupSelection $setupContext (Get-CopyQSetupPreview $setupContext $profile)
        $installed.result | Should Be 'installed'
        Invoke-CopyQSetupProcess $setupContext @('eval','var c=commands();for(var i=0;i<c.length;i++)if(c[i].internalId==="canonical.smart-title")c[i].name=c[i].name.toUpperCase();setCommands(c)') | Out-Null
        {Restore-CopyQSetupCommands $setupContext $installed.receipt} | Should Throw 'RESTORE_STATE_CHANGED'
    }
}
