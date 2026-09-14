#Requires -Version 7.2
# No package downloads or clipboard-history operations.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CopyQTextDigest([string] $Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}

function Resolve-CopyQPackagePath([string] $Root, [string] $Relative) {
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[/\\])\.\.([/\\]|$)' -or $Relative.Contains(':')) { throw 'PACKAGE_PATH_INVALID' }
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('/','\') + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (-not $resolved.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw 'PACKAGE_PATH_INVALID' }
    return $resolved
}

function New-CopyQSetupProfile {
    param([string[]] $Commands = @('canonical.dispatcher','canonical.undo-delete','canonical.show-frequent'), [string] $PackageDigest = '')
    @{ schema = 1; commands = @($Commands); shortcuts = @{}; packageDigest = $PackageDigest; azureRegion = '' }
}

function Assert-CopyQSetupProfile($Profile) {
    if ($Profile -isnot [Collections.IDictionary]) { throw 'PROFILE_INVALID' }
    foreach ($key in $Profile.Keys) { if ($key -notin @('schema','commands','shortcuts','packageDigest','azureRegion')) { throw 'PROFILE_UNKNOWN_FIELD' } }
    if ($Profile.schema -ne 1 -or $Profile.commands -isnot [array] -or $Profile.commands.Count -eq 0) { throw 'PROFILE_INVALID' }
    foreach ($id in $Profile.commands) { if ($id -isnot [string] -or $id -notmatch '^(canonical|moonlander)\.[a-z0-9-]+$') { throw 'PROFILE_COMMAND_INVALID' } }
    if ($Profile.shortcuts -isnot [Collections.IDictionary]) { throw 'PROFILE_SHORTCUT_INVALID' }
    foreach ($id in $Profile.shortcuts.Keys) {
        if ($id -notin $Profile.commands) { throw 'PROFILE_SHORTCUT_UNSELECTED' }
        $entry = $Profile.shortcuts[$id]
        if ($entry -isnot [Collections.IDictionary] -or $entry.Count -ne 2 -or -not $entry.Contains('local') -or -not $entry.Contains('global')) { throw 'PROFILE_SHORTCUT_INVALID' }
        foreach ($scope in @('local','global')) {
            if ($entry[$scope] -isnot [array]) { throw 'PROFILE_SHORTCUT_INVALID' }
            foreach ($shortcut in $entry[$scope]) {
                if ($shortcut -isnot [string] -or $shortcut -notmatch '^(?:(?:Ctrl|Alt|Shift|Meta)\+)*(?:F(?:[1-9]|[12][0-9]|3[0-5])|[A-Z0-9]|Delete|Insert|Space|Tab|Home|End|Up|Down|Left|Right|Escape)$') { throw 'PROFILE_SHORTCUT_INVALID' }
            }
        }
    }
    if ($Profile.packageDigest -and $Profile.packageDigest -notmatch '^[a-f0-9]{64}$') { throw 'PROFILE_DIGEST_INVALID' }
    if ($Profile.azureRegion -and $Profile.azureRegion -notmatch '^[a-z0-9-]{1,64}$') { throw 'PROFILE_REGION_INVALID' }
}

function Save-CopyQSetupProfile($Profile, [string] $Path) {
    Assert-CopyQSetupProfile $Profile
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($Path), ($Profile | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}

function Read-CopyQSetupProfile([string] $Path) {
    if ((Get-Item -LiteralPath $Path).Length -gt 1MB) { throw 'PROFILE_TOO_LARGE' }
    try { $profile = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable } catch { throw 'PROFILE_JSON_INVALID' }
    Assert-CopyQSetupProfile $profile
    return $profile
}

function Get-CopyQSetupPackage([string] $Root) {
    $rootPath = [IO.Path]::GetFullPath($Root)
    $manifest = Get-Content -LiteralPath (Join-Path $rootPath 'manifest/public-commands.json') -Raw | ConvertFrom-Json
    $catalog = @($manifest.commands) + @($manifest.alternatives) | ForEach-Object {
        $path = Resolve-CopyQPackagePath $rootPath $_.output
        [pscustomobject]@{ id=$_.identity; name=$_.name; dependencies=@($_.dependencies); ini=[IO.File]::ReadAllText($path); path=$_.output }
    }
    $identity = @($catalog | ForEach-Object { $_.id + ':' + (Get-CopyQTextDigest ($_.ini -replace "`r`n","`n")) })
    foreach ($file in @('modules/CopyQ.Setup.psm1','scripts/setup/command-plan.js','scripts/setup/bridge.js')) {
        $identity += $file + ':' + (Get-CopyQTextDigest ([IO.File]::ReadAllText((Join-Path $rootPath $file)) -replace "`r`n","`n"))
    }
    [pscustomobject]@{ Root=$rootPath; Catalog=@($catalog); Version=$manifest.copyqVersion; Digest=(Get-CopyQTextDigest ($identity -join "`n")) }
}

function New-CopyQSetupContext {
    param([string] $Root = (Split-Path -Parent $PSScriptRoot), [string] $Executable,
          [string] $Session = '', [string] $StateRoot = (Join-Path $env:LOCALAPPDATA 'CopyQCommandSuite/setup'))
    if (-not $Executable) {
        $found = Get-Command copyq.exe -ErrorAction SilentlyContinue
        $Executable = if ($found) { $found.Source } else { Join-Path $env:ProgramFiles 'CopyQ/copyq.exe' }
    }
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { throw 'COPYQ_NOT_INSTALLED' }
    $package = Get-CopyQSetupPackage $Root
    $statePath = [IO.Path]::GetFullPath($StateRoot)
    $repoPrefix = $package.Root.TrimEnd('/','\') + [IO.Path]::DirectorySeparatorChar
    if ($statePath -eq $package.Root -or $statePath.StartsWith($repoPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'STATE_MUST_BE_OUTSIDE_PACKAGE' }
    [pscustomobject]@{ Package=$package; Executable=[IO.Path]::GetFullPath($Executable); Session=$Session; StateRoot=$statePath }
}

function Invoke-CopyQSetupProcess($Context, [string[]] $Arguments, [string] $InputText = '', [int] $TimeoutSeconds = 20) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Context.Executable
    if ($Context.Session) { $start.ArgumentList.Add('-s'); $start.ArgumentList.Add($Context.Session) }
    foreach ($arg in $Arguments) { $start.ArgumentList.Add($arg) }
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardInput=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $start.StandardInputEncoding=[Text.UTF8Encoding]::new($false)
    $start.StandardOutputEncoding=[Text.Encoding]::UTF8; $start.StandardErrorEncoding=[Text.Encoding]::UTF8
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
    try {
        [void]$process.Start()
        $out=$process.StandardOutput.ReadToEndAsync(); $err=$process.StandardError.ReadToEndAsync()
        $write=$process.StandardInput.WriteAsync($InputText)
        if (-not $write.Wait($TimeoutSeconds * 1000)) { $process.Kill(); throw 'COPYQ_TIMEOUT' }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) { $process.Kill(); throw 'COPYQ_TIMEOUT' }
        $stderr=$err.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            $reason = [regex]::Match($stderr,'(?:COMMAND_STATE_CHANGED|DUPLICATE_IDENTITY|SHORTCUT_CONFLICT|NAME_CONFLICT|PROTECTION_CONFLICT|UNKNOWN_COMMAND|PACKAGE_IDENTITY_INVALID)')
            if ($reason.Success) { throw $reason.Value }
            throw 'COPYQ_REQUEST_FAILED'
        }
        return $out.GetAwaiter().GetResult().TrimEnd("`r","`n")
    } finally { $process.Dispose() }
}

function Invoke-CopyQSetupBridge($Context, $Request) {
    $json = $Request | ConvertTo-Json -Depth 20 -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    $program = "var request = JSON.parse(str(fromBase64('$encoded')));`n" +
        [IO.File]::ReadAllText((Join-Path $Context.Package.Root 'scripts/setup/command-plan.js')) + "`n" +
        [IO.File]::ReadAllText((Join-Path $Context.Package.Root 'scripts/setup/bridge.js'))
    Invoke-CopyQSetupProcess $Context @('eval','-') $program | ConvertFrom-Json
}

function Get-CopyQSetupSnapshot($Context) { Invoke-CopyQSetupBridge $Context @{action='snapshot'} }

function Get-CopyQSetupPreview($Context, $Profile) {
    Assert-CopyQSetupProfile $Profile
    $version = Invoke-CopyQSetupProcess $Context @('--version')
    if ($version -notmatch '^CopyQ Clipboard Manager v?16\.0\.0(?:\s|$)') { throw 'COPYQ_16_REQUIRED' }
    $fresh = Get-CopyQSetupPackage $Context.Package.Root
    if ($fresh.Digest -ne $Context.Package.Digest) { throw 'PACKAGE_CHANGED' }
    $preview = Invoke-CopyQSetupBridge $Context @{action='preview';ids=$Profile.commands;catalog=$fresh.Catalog;shortcuts=$Profile.shortcuts}
    $preview | Add-Member NoteProperty packageDigest $fresh.Digest
    $dependencyStatus=Get-CopyQSetupDependencyStatus $Context $preview.selected
    $preview | Add-Member NoteProperty missingDependencies @($dependencyStatus.missingDependencies)
    return $preview
}

function Write-CopyQSetupReceipt($Receipt, [string] $Path) {
    $temporary = $Path + '.pending'
    [IO.File]::WriteAllText($temporary, ($Receipt | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary,$Path,$true)
}

function Install-CopyQSetupSelection($Context, $Preview) {
    if ((Get-CopyQSetupPackage $Context.Package.Root).Digest -ne $Preview.packageDigest) { throw 'PACKAGE_CHANGED' }
    $current = Get-CopyQSetupSnapshot $Context
    if ($current.native -cne $Preview.before) { throw 'COMMAND_STATE_CHANGED' }
    $dependencyStatus=Get-CopyQSetupDependencyStatus $Context $Preview.selected
    if (-not $dependencyStatus.ready) { throw ('DEPENDENCIES_MISSING: ' + ($dependencyStatus.missingDependencies -join '; ') + '. Prepare these dependencies or deselect their commands, then preview again.') }
    if ($Preview.before -ceq $Preview.candidate) { return [pscustomobject]@{result='unchanged';receipt=$null;selected=$Preview.selected} }
    $attempt = [guid]::NewGuid().ToString('N')
    $directory = Join-Path $Context.StateRoot ('attempt-' + $attempt)
    [void][IO.Directory]::CreateDirectory($directory)
    $receiptPath = Join-Path $directory 'receipt.json'
    $beforePath = Join-Path $directory 'before.ini'; $candidatePath = Join-Path $directory 'candidate.ini'
    [IO.File]::WriteAllText($beforePath,$Preview.before,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($candidatePath,$Preview.candidate,[Text.UTF8Encoding]::new($false))
    $receipt = [ordered]@{ schema=1; attempt=$attempt; result='prepared'; packageDigest=$Preview.packageDigest;
        beforeDigest=(Get-CopyQTextDigest $Preview.before); candidateDigest=(Get-CopyQTextDigest $Preview.candidate);
        session=$Context.Session; selected=@($Preview.selected); timestamp=[DateTime]::UtcNow.ToString('o');
        reason=''; next='verify-or-restore'; rollback='available' }
    Write-CopyQSetupReceipt $receipt $receiptPath
    try {
        $after = Invoke-CopyQSetupBridge $Context @{action='apply';expected=$Preview.before;candidate=$Preview.candidate}
        if ($after.native -cne $Preview.candidate) { throw 'INSTALLED_COMMAND_MISMATCH' }
        $readback = Get-CopyQSetupSnapshot $Context
        if ($readback.native -cne $Preview.candidate) { throw 'INSTALLED_COMMAND_MISMATCH' }
        $receipt.result='installed'; $receipt.next='verify-features'; Write-CopyQSetupReceipt $receipt $receiptPath
        return [pscustomobject]@{result='installed';receipt=$receiptPath;selected=$Preview.selected}
    } catch {
        $receipt.result='failed'
        $reason=$_.Exception.Message
        $receipt.reason=if ($reason -match '^[A-Z_]+$') {$reason} else {'INSTALL_FAILED'}
        try {
            $now=Get-CopyQSetupSnapshot $Context
            if ($now.native -ceq $Preview.before) { $receipt.rollback='not-required'; $receipt.next='preview' }
            elseif ($now.native -ceq $Preview.candidate) {
                $restored=Invoke-CopyQSetupBridge $Context @{action='apply';expected=$Preview.candidate;candidate=$Preview.before}
                if ($restored.native -cne $Preview.before) { throw 'RESTORE_VERIFY_FAILED' }
                $receipt.rollback='restored'; $receipt.next='preview'
            } else { $receipt.rollback='refused-drift'; $receipt.next='inspect-commands' }
        } catch { $receipt.rollback='unverified'; $receipt.next='verify-or-restore' }
        Write-CopyQSetupReceipt $receipt $receiptPath
        throw ($receipt.reason + '; recovery receipt: ' + $receiptPath)
    }
}

function Restore-CopyQSetupCommands($Context, [string] $ReceiptPath) {
    $path=[IO.Path]::GetFullPath($ReceiptPath)
    $receipt=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    if ($receipt.schema -ne 1 -or $receipt.session -ne $Context.Session) { throw 'RESTORE_RECEIPT_INVALID' }
    $before=[IO.File]::ReadAllText((Join-Path (Split-Path -Parent $path) 'before.ini'))
    $candidate=[IO.File]::ReadAllText((Join-Path (Split-Path -Parent $path) 'candidate.ini'))
    if ((Get-CopyQTextDigest $before) -ne $receipt.beforeDigest -or (Get-CopyQTextDigest $candidate) -ne $receipt.candidateDigest) { throw 'RESTORE_BACKUP_CHANGED' }
    $current=Get-CopyQSetupSnapshot $Context
    if ($current.native -cne $before) {
        if ($current.native -cne $candidate) { throw 'RESTORE_STATE_CHANGED' }
        $after=Invoke-CopyQSetupBridge $Context @{action='apply';expected=$candidate;candidate=$before}
        if ($after.native -cne $before) { throw 'RESTORE_VERIFY_FAILED' }
    }
    $receipt.result='restored';$receipt.rollback='restored';$receipt.next='preview'
    Write-CopyQSetupReceipt $receipt $path
    [pscustomobject]@{result='restored';receipt=$path}
}

function Test-CopyQSetupInstallation($Context, $Profile) {
    $preview=Get-CopyQSetupPreview $Context $Profile
    $matching=$preview.before -ceq $preview.candidate
    if (-not $matching) {
        return [pscustomobject]@{definitionsVerified=$false;helperChecks=@();helpersPassed=$false;
            missingDependencies=@();dependencyChecksRun=$false;reason='COMMAND_DEFINITIONS_DIFFER';
            externalServicesTested=$false;clipboardPasteTested=$false}
    }
    $checks=@(Invoke-CopyQSetupBridge $Context @{action='helpers';ids=$preview.selected;expected=$preview.candidate})
    $dependencyStatus=Get-CopyQSetupDependencyStatus $Context $preview.selected
    [pscustomobject]@{definitionsVerified=$matching;helperChecks=$checks;helpersPassed=(@($checks | Where-Object {-not $_.passed}).Count -eq 0);
        missingDependencies=@($dependencyStatus.missingDependencies);dependencyChecksRun=$true; externalServicesTested=$false; clipboardPasteTested=$false }
}

function Get-CopyQSetupDependencyStatus($Context, [string[]] $Ids, [string] $LocalAppData=$env:LOCALAPPDATA) {
    $dependencies=& (Join-Path $Context.Package.Root 'scripts/Test-Dependencies.ps1') -LocalAppData $LocalAppData -AsJson | ConvertFrom-Json
    $missing=[Collections.Generic.List[string]]::new()
    foreach ($id in $Ids) {
        switch ($id) {
            'canonical.markdown-render' { if (-not $dependencies.Marked.Available) {$missing.Add('marked')} }
            'canonical.pygments-highlight' { if (-not $dependencies.Pygments.Available) {$missing.Add('Python with Pygments')} }
            'canonical.ocr' { if (-not ($dependencies.Tesseract.Available -and $dependencies.TesseractLanguages.English -and $dependencies.TesseractLanguages.Hebrew)) {$missing.Add('Tesseract with eng+heb')} }
            'canonical.translate-en' {
                $helperRoot=Join-Path $LocalAppData 'CopyQCommandSuite/translation'
                foreach ($name in @('Invoke-CopyQAzureTranslation.ps1','CopyQ.Translation.psm1')) {
                    if (-not (Test-Path -LiteralPath (Join-Path $helperRoot $name) -PathType Leaf)) {$missing.Add('Azure helper: '+$name)}
                }
                if (-not (Test-Path -LiteralPath (Join-Path $LocalAppData 'CopyQTranslation/azure-key.dpapi') -PathType Leaf)) {$missing.Add('Azure encrypted credential')}
                try {
                    $configuration=Get-Content -LiteralPath (Join-Path $LocalAppData 'CopyQTranslation/translator.json') -Raw | ConvertFrom-Json
                    if (([string]$configuration.region).Trim().ToLowerInvariant() -notmatch '^[a-z0-9]+$') {throw 'invalid region'}
                } catch {$missing.Add('Azure region configuration')}
            }
            {$_ -like 'moonlander.*'} { if (-not $dependencies.Moonlander.Available -and -not $missing.Contains('Moonlander companion')) {$missing.Add('Moonlander companion')} }
        }
    }
    [pscustomobject]@{ready=($missing.Count -eq 0);missingDependencies=@($missing)}
}

function Export-CopyQSetupProfile($Context) {
    $current=Get-CopyQSetupSnapshot $Context
    $known=@($Context.Package.Catalog.id)
    $chosen=@($current.inventory | Where-Object {$_.id -in $known})
    if (-not $chosen.Count) { throw 'NO_SUITE_COMMANDS_INSTALLED' }
    $profile=New-CopyQSetupProfile -Commands @($chosen.id) -PackageDigest $Context.Package.Digest
    foreach ($c in $chosen) { $profile.shortcuts[$c.id]=@{local=@($c.local);global=@($c.global)} }
    return $profile
}

Export-ModuleMember -Function *-CopyQ*
