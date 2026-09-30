$ErrorActionPreference = 'Stop'

Describe 'Isolated CopyQ 16 runtime acceptance' {
    BeforeAll {
        $script:CopyQ = Join-Path $env:ProgramFiles 'CopyQ\copyq.exe'
        $script:Session = 'cqrt-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
        $script:PrivateRoot = [IO.Path]::GetFullPath((Join-Path $env:TEMP $script:Session))
        $tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
        if (-not $script:PrivateRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "PRIVATE_PATH_OUTSIDE_TEMP: $script:PrivateRoot"
        }
        $script:PreviousSettings = [Environment]::GetEnvironmentVariable('COPYQ_SETTINGS_PATH', 'Process')
        $script:PreviousItems = [Environment]::GetEnvironmentVariable('COPYQ_ITEM_DATA_PATH', 'Process')
        $env:COPYQ_SETTINGS_PATH = Join-Path $script:PrivateRoot 'settings'
        $env:COPYQ_ITEM_DATA_PATH = Join-Path $script:PrivateRoot 'items'

        function Invoke-IsolatedCopyQ {
            param([Parameter(Mandatory)][string[]] $Arguments, [string] $InputText)
            $start = [Diagnostics.ProcessStartInfo]::new()
            $start.FileName = $script:CopyQ
            foreach ($argument in @('-s', $script:Session) + $Arguments) { [void] $start.ArgumentList.Add($argument) }
            $start.UseShellExecute = $false
            $start.CreateNoWindow = $true
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            $start.RedirectStandardInput = $null -ne $InputText
            $process = [Diagnostics.Process]::new()
            $process.StartInfo = $start
            try {
                [void] $process.Start()
                # Drain both pipes concurrently: CopyQ can emit a large script
                # backtrace even for an exception caught by a test fixture.
                $stdoutTask = $process.StandardOutput.ReadToEndAsync()
                $stderrTask = $process.StandardError.ReadToEndAsync()
                if ($null -ne $InputText) {
                    $process.StandardInput.Write($InputText)
                    $process.StandardInput.Close()
                }
                if (-not $process.WaitForExit(30000)) {
                    $process.Kill()
                    throw 'ISOLATED_COPYQ_COMMAND_TIMEOUT'
                }
                $stdout = $stdoutTask.GetAwaiter().GetResult()
                $stderr = $stderrTask.GetAwaiter().GetResult()
                [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout.Trim(); StdErr = $stderr.Trim() }
            } finally {
                $process.Dispose()
            }
        }

        function Invoke-IsolatedEval {
            param([Parameter(Mandatory)][string] $Program)
            $result = Invoke-IsolatedCopyQ -Arguments @('eval', '-') -InputText $Program
            if ($result.ExitCode -ne 0) { throw "COPYQ_EVAL_FAILED: $($result.StdErr)" }
            $result.StdOut
        }

        function Start-IsolatedCopyQ {
            $script:ServerProcess = Start-Process -FilePath $script:CopyQ -ArgumentList @('-s', $script:Session) -WindowStyle Hidden -PassThru
            for ($attempt = 0; $attempt -lt 50; $attempt += 1) {
                Start-Sleep -Milliseconds 100
                $probe = Invoke-IsolatedCopyQ -Arguments @('tab')
                if ($probe.ExitCode -eq 0) { return }
            }
            throw 'ISOLATED_COPYQ_NOT_READY'
        }

        Start-IsolatedCopyQ
        $bundle = [IO.File]::ReadAllText((Join-Path (Split-Path -Parent $PSScriptRoot) 'commands\bundles\all.ini'))
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bundle))
        # Do not show real Windows notifications from synthetic automatic events.
        # Keep the real asynchronous API available for the dedicated worker test.
        $transport = 'global.testRealAction=global.action;global.action=function(code){if(str(code).indexOf("nativeSecretNotice")>=0){settings("test_notice_code",str(code));return;}return testRealAction.apply(this,arguments);};'
        $transport64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($transport))
        Invoke-IsolatedEval "var imported=importCommands(str(fromBase64('$encoded')));imported.push({name:'Test notification transport',isScript:true,cmd:str(fromBase64('$transport64'))});setCommands(imported);String(commands().filter(function(c){return /^(?:canonical|moonlander)\./.test(c.internalId||'');}).length)" | Should Be '18'
        Invoke-IsolatedCopyQ -Arguments @('exit') | Out-Null
        if (-not $script:ServerProcess.WaitForExit(5000)) { throw 'ISOLATED_COPYQ_DID_NOT_EXIT' }
        Start-IsolatedCopyQ
    }

    AfterAll {
        if ($script:CopyQ -and $script:Session) {
            Invoke-IsolatedCopyQ -Arguments @('exit') | Out-Null
            if ($script:ServerProcess) { $null = $script:ServerProcess.WaitForExit(5000) }
        }
        if ($null -eq $script:PreviousSettings) { Remove-Item Env:COPYQ_SETTINGS_PATH -ErrorAction SilentlyContinue } else { $env:COPYQ_SETTINGS_PATH = $script:PreviousSettings }
        if ($null -eq $script:PreviousItems) { Remove-Item Env:COPYQ_ITEM_DATA_PATH -ErrorAction SilentlyContinue } else { $env:COPYQ_ITEM_DATA_PATH = $script:PreviousItems }
        if ($script:PrivateRoot -and (Test-Path -LiteralPath $script:PrivateRoot)) {
            $resolved = [IO.Path]::GetFullPath($script:PrivateRoot)
            $tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
            if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "REFUSING_PRIVATE_DELETE: $resolved" }
            for ($attempt = 0; $attempt -lt 20; $attempt += 1) {
                try { Remove-Item -LiteralPath $resolved -Recurse -Force; break }
                catch { if ($attempt -eq 19) { throw }; Start-Sleep -Milliseconds 100 }
            }
        }
    }

    It 'loads the exact candidate and preserves shortcut ownership' {
        $json = Invoke-IsolatedEval "JSON.stringify(commands().filter(function(c){return /^(?:canonical|moonlander)\./.test(c.internalId||'');}).map(function(c){return {id:c.internalId,isScript:!!c.isScript,global:c.globalShortcuts||[],local:c.shortcuts||[]};}))"
        $commands = @($json | ConvertFrom-Json)
        $commands.Count | Should Be 18
        ($commands | Where-Object id -eq 'canonical.undoable-delete-listener').isScript | Should Be $true
        ($commands | Where-Object id -eq 'canonical.undo-delete').local | Should Be @('ctrl+z')
        ($commands | Where-Object id -eq 'moonlander.smart-title').global | Should Be @('F13')
        ($commands | Where-Object id -eq 'moonlander.cycle-case').global | Should Be @('F19')
        ($commands | Where-Object id -eq 'moonlander.hebrew-layout').global | Should Be @('F22')
    }

    It 'moves only the removed item to trash and restores its complete MIME data' {
        Invoke-IsolatedEval "tab('Runtime Test');insert(0,'second');var a={};a[mimeText]='first';a[mimeHtml]='<b>first</b>';a['application/x-copyq-test-binary']=fromBase64('AAEC');insert(0,a);remove(0);'DONE'" | Should Be 'DONE'
        $trashed = Invoke-IsolatedEval "tab('(trash)');JSON.stringify({count:size(),text:str(read(mimeText,0)),html:str(read(mimeHtml,0)),binary:str(toBase64(read('application/x-copyq-test-binary',0))),source:str(read('application/x-copyq-trash-source-tab',0)),batch:str(read('application/x-copyq-trash-batch',0))})" | ConvertFrom-Json
        $trashed.count | Should Be 1
        $trashed.text | Should Be 'first'
        $trashed.html | Should Be '<b>first</b>'
        $trashed.binary | Should Be 'AAEC'
        $trashed.source | Should Be 'Runtime Test'
        $trashed.batch | Should Not BeNullOrEmpty
        Invoke-IsolatedEval "var c=commands().filter(function(x){return x.internalId==='canonical.undo-delete';})[0];eval(c.cmd.replace(/^copyq:\\s*/,''));'UNDONE'" | Should Be 'UNDONE'
        $restored = Invoke-IsolatedEval "tab('Runtime Test');JSON.stringify({count:size(),top:str(read(mimeText,0)),second:str(read(mimeText,1))})" | ConvertFrom-Json
        $restored.count | Should Be 2
        $restored.top | Should Be 'first'
        $restored.second | Should Be 'second'
        $formats = Invoke-IsolatedEval "tab('Runtime Test');var item=getItem(0);JSON.stringify({html:str(read(mimeHtml,0)),binary:str(toBase64(read('application/x-copyq-test-binary',0))),restore:Object.prototype.hasOwnProperty.call(item,'application/x-copyq-undo-restore-batch')})" | ConvertFrom-Json
        $formats.html | Should Be '<b>first</b>'
        $formats.binary | Should Be 'AAEC'
        $formats.restore | Should Be $false
        Invoke-IsolatedEval "tab('(trash)');String(size())" | Should Be '0'
    }

    It 'restores a multi-item deletion batch in its original order' {
        Invoke-IsolatedEval "tab('Batch Test');insert(0,'third');insert(0,'second');insert(0,'first');remove(0,1);'DELETED'" | Should Be 'DELETED'
        $batch = Invoke-IsolatedEval "tab('(trash)');JSON.stringify({count:size(),first:str(read('application/x-copyq-trash-batch',0)),second:str(read('application/x-copyq-trash-batch',1))})" | ConvertFrom-Json
        $batch.count | Should Be 2
        $batch.first | Should Not BeNullOrEmpty
        $batch.second | Should Be $batch.first
        Invoke-IsolatedEval "var c=commands().filter(function(x){return x.internalId==='canonical.undo-delete';})[0];eval(c.cmd.replace(/^copyq:\s*/,''));'UNDONE'" | Should Be 'UNDONE'
        $restored = Invoke-IsolatedEval "tab('Batch Test');JSON.stringify([str(read(mimeText,0)),str(read(mimeText,1)),str(read(mimeText,2))])" | ConvertFrom-Json
        $restored | Should Be @('first', 'second', 'third')
        Invoke-IsolatedEval "tab('Batch Test');String(ItemSelection('Batch Test').select(/.+/,'application/x-copyq-undo-restore-batch').length)" | Should Be '0'
        Invoke-IsolatedEval "tab('(trash)');String(size())" | Should Be '0'
    }

    It 'falls back to Clipboard and strips private metadata when the source tab is gone' {
        Invoke-IsolatedEval "tab('Missing Source');var item={};item[mimeText]='fallback item';item['application/x-copyq-user-frequency-key']='v3:private:first';item['application/x-copyq-user-frequency-count']='9';insert(0,item);remove(0);removeTab('Missing Source');'DELETED'" | Should Be 'DELETED'
        Invoke-IsolatedEval "var c=commands().filter(function(x){return x.internalId==='canonical.undo-delete';})[0];eval(c.cmd.replace(/^copyq:\s*/,''));'UNDONE'" | Should Be 'UNDONE'
        $fallback = Invoke-IsolatedEval "var found=ItemSelection('&Clipboard').select(/^fallback item$/,mimeText);var item=found.itemAtIndex(0);JSON.stringify({matches:found.length,freq:Object.prototype.hasOwnProperty.call(item,'application/x-copyq-user-frequency-key'),trash:Object.prototype.hasOwnProperty.call(item,'application/x-copyq-trash-source-tab')})" | ConvertFrom-Json
        $fallback.matches | Should Be 1
        $fallback.freq | Should Be $false
        $fallback.trash | Should Be $false
        Invoke-IsolatedEval "tab('(trash)');String(size())" | Should Be '0'
    }

    It 'keeps removal-hook helpers isolated from narrow command modules' {
        $probe = Invoke-IsolatedEval "var command=commands().filter(function(c){return c.internalId==='canonical.regex-search';})[0];var body=command.cmd.replace(/^copyq:\s*/,'');var core=body.substring(0,body.indexOf('var query = dialog'));eval(core);if(typeof CopyQCore.validateRegex!=='function'||typeof CopyQCore.isTrashExpired!=='undefined')throw new Error('PROBE_NOT_NARROW');tab('(trash)');var old={};old[mimeText]='scope probe expired';old['application/x-copyq-trash-deleted-at']='2000-01-01T00:00:00.000Z';insert(0,old);tab('Module Isolation');insert(0,'module isolation deletion');remove(0);tab('(trash)');JSON.stringify({text:str(read(mimeText,0)),source:str(read('application/x-copyq-trash-source-tab',0))})" | ConvertFrom-Json
        $probe.text | Should Be 'module isolation deletion'
        $probe.source | Should Be 'Module Isolation'
        Invoke-IsolatedEval "String(ItemSelection('(trash)').select(/^scope probe expired$/,mimeText).length)" | Should Be '0'
        Invoke-IsolatedEval "tab('(trash)');remove(0);'CLEAN'" | Should Be 'CLEAN'
    }

    It 'prunes expired trash lazily before recording a new batch' {
        Invoke-IsolatedEval "tab('(trash)');var old={};old[mimeText]='expired';old['application/x-copyq-trash-source-tab']='Old';old['application/x-copyq-trash-source-row']='0';old['application/x-copyq-trash-batch']='old';old['application/x-copyq-trash-deleted-at']='2000-01-01T00:00:00.000Z';insert(0,old);tab('Cleanup Test');insert(0,'fresh deletion');remove(0);'DONE'" | Should Be 'DONE'
        $trash = Invoke-IsolatedEval "tab('(trash)');JSON.stringify({count:size(),text:str(read(mimeText,0))})" | ConvertFrom-Json
        $trash.count | Should Be 1
        $trash.text | Should Be 'fresh deletion'
        Invoke-IsolatedEval "tab('(trash)');remove(0);String(size())" | Should Be '0'
    }

    It 'rolls back frequency state and keeps the source when the trash transaction fails' {
        $beforeTrash = [int] (Invoke-IsolatedEval "tab('(trash)');String(size())")
        $failureKey = 'v3:failure-first:failure-second'
        $failureState = '{"version":3,"clock":1,"counters":{"' + $failureKey + '":{"version":3,"first":"failure-first","second":"failure-second","count":7,"lastUsed":1}}}'
        Invoke-IsolatedEval "settings('frequent_usage_counts_v3','$failureState');tab('Frequent');var item={};item[mimeText]='must remain';item['application/x-copyq-user-frequency-key']='$failureKey';item['application/x-copyq-user-frequency-count']='7';insert(0,item);show('Frequent');selectItems(0);'READY'" | Should Be 'READY'
        $writeNeedle = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('tab(TRASH_TAB); write(0, items);'))
        $writeFailure = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("tab(TRASH_TAB); throw new Error('TEST_WRITE_BLOCKED'); write(0, items);"))
        $handlerNeedle = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('global.onItemsRemoved = function () {'))
        $handlerAlias = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('global.onItemsRemoved = copyqTestOnItemsRemoved = function () {'))
        $priorNeedle = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('var onItemsRemoved_ = global.onItemsRemoved || function () {};'))
        $priorNoop = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('var onItemsRemoved_ = function () {};'))
        $failureScript = "var listener=commands().filter(function(c){return c.internalId==='canonical.undoable-delete-listener';})[0];var body=listener.cmd;"
        $failureScript += "body=body.replace(str(fromBase64('$writeNeedle')),str(fromBase64('$writeFailure')));"
        $failureScript += "body=body.replace(str(fromBase64('$handlerNeedle')),str(fromBase64('$handlerAlias')));"
        $failureScript += "body=body.replace(str(fromBase64('$priorNeedle')),str(fromBase64('$priorNoop')));"
        $failureScript += 'eval(body);copyqTestOnItemsRemoved()'
        Invoke-IsolatedCopyQ -Arguments @('eval', '-') -InputText $failureScript | Out-Null
        Invoke-IsolatedEval "var state=JSON.parse(settings('frequent_usage_counts_v3'));tab('Frequent');JSON.stringify({count:size(),text:str(read(mimeText,0)),frequency:state.counters['$failureKey'].count})" | ConvertFrom-Json | ForEach-Object {
            $_.count | Should Be 1
            $_.text | Should Be 'must remain'
            $_.frequency | Should Be 7
        }
        [int] (Invoke-IsolatedEval "tab('(trash)');String(size())") | Should Be $beforeTrash
        Invoke-IsolatedEval "tab('Frequent');remove(0);tab('(trash)');remove(0);'CLEAN'" | Should Be 'CLEAN'
    }

    It 'resets and restores a Frequent counter without duplicating the entry' {
        $key = 'v3:test-first:test-second'
        $state = '{"version":3,"clock":1,"counters":{"' + $key + '":{"version":3,"first":"test-first","second":"test-second","count":7,"lastUsed":1}}}'
        Invoke-IsolatedEval "settings('frequent_usage_counts_v3','$state');tab('Frequent');var item={};item[mimeText]='repeat me';item['application/x-copyq-user-frequency-key']='$key';item['application/x-copyq-user-frequency-count']='7';insert(0,item);remove(0);'DELETED'" | Should Be 'DELETED'
        $dismissed = Invoke-IsolatedEval "var s=JSON.parse(settings('frequent_usage_counts_v3'));String(s.counters['$key'].count)"
        $dismissed | Should Be '0'
        Invoke-IsolatedEval "var c=commands().filter(function(x){return x.internalId==='canonical.undo-delete';})[0];eval(c.cmd.replace(/^copyq:\\s*/,''));'UNDONE'" | Should Be 'UNDONE'
        $restored = Invoke-IsolatedEval "var s=JSON.parse(settings('frequent_usage_counts_v3'));tab('Frequent');JSON.stringify({count:s.counters['$key'].count,items:size(),text:str(read(mimeText,0))})" | ConvertFrom-Json
        $restored.count | Should Be 7
        $restored.items | Should Be 1
        $restored.text | Should Be 'repeat me'
    }

    It 'runs the dispatcher without consuming primary placement and builds the Frequent index' {
        Invoke-IsolatedEval "if(tab().indexOf('Frequent')>=0)removeTab('Frequent');String(tab().indexOf('Frequent'))" | Should Be '-1'
        $beforeKeys = @(Invoke-IsolatedEval "var value=settings('frequent_usage_counts_v3');var state=value?JSON.parse(value):{counters:{}};JSON.stringify(Object.keys(state.counters))" | ConvertFrom-Json)
        Invoke-IsolatedEval "tab('Dispatcher Input');insert(0,'  index me  ');'READY'" | Should Be 'READY'
        $key = $null
        for ($copyNumber = 1; $copyNumber -le 6; $copyNumber += 1) {
            Invoke-IsolatedEval "setData(mimeText,'  index me  ');setData(mimeOutputTab,'Dispatcher Input');if(runAutomaticCommands())saveData();'STARTED'" | Should Be 'STARTED'
            for ($attempt = 0; $attempt -lt 40; $attempt += 1) {
                Start-Sleep -Milliseconds 50
                $snapshot = Invoke-IsolatedEval "var state=JSON.parse(settings('frequent_usage_counts_v3'));JSON.stringify(state.counters)" | ConvertFrom-Json
                if (-not $key) { $key = @($snapshot.PSObject.Properties.Name | Where-Object { $_ -notin $beforeKeys })[0] }
                if ($key -and $snapshot.$key.count -eq $copyNumber) { break }
            }
            $snapshot.$key.count | Should Be $copyNumber
        }
        $result = Invoke-IsolatedEval "var state=JSON.parse(settings('frequent_usage_counts_v3'));var key='$key';tab('Frequent');var found=ItemSelection('Frequent').select(new RegExp('^'+key+'$'),'application/x-copyq-user-frequency-key');JSON.stringify({matches:found.length,text:found.length?str(found.itemAtIndex(0)[mimeText]):'',key:key,stateCount:state.counters[key].count})" | ConvertFrom-Json
        $result.matches | Should Be 1
        $result.text | Should Be 'index me'
        $result.key | Should Match '^v3:'
        $result.stateCount | Should Be 6
        $primary = Invoke-IsolatedEval "tab('Dispatcher Input');JSON.stringify({count:size(),text:str(read(mimeText,0))})" | ConvertFrom-Json
        $primary.count | Should Be 1
        $primary.text | Should Be '  index me  '
    }

    It 'routes URLs through real automatic commands and saves them without a network request' {
        foreach ($url in @('https://example.test/feed.ics', 'https://localhost:8200', 'https://192.168.1.2:8443', 'ftps://example.test/file', 'file:///D:/images/a photo.jpeg')) {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($url))
            $result = Invoke-IsolatedEval "setData(mimeText,fromBase64('$encoded'));setData(mimeOutputTab,'URL Fallback Test');var accepted=runAutomaticCommands();if(accepted)saveData();JSON.stringify({accepted:accepted,destination:str(data(mimeOutputTab))})" | ConvertFrom-Json
            $result.accepted | Should Be $true
            $result.destination | Should Be '&URLs'
            Invoke-IsolatedEval "tab('&URLs');str(read(mimeText,0))" | Should Be $url
        }
        Invoke-IsolatedEval "String(tab().indexOf('URL Fallback Test'))" | Should Be '-1'
    }

    It 'stores compact JSON intact while preserving standalone and embedded secret protection' {
        $cases = @(
            @{Text='Collegiate'; Accepted=$true; Stored='Collegiate'; Destination='Password Boundary Test'},
            @{Text='Collegiate '; Accepted=$true; Stored='Collegiate '; Destination='Password Boundary Test'},
            @{Text='550e8400-e29b-41d4-a716-446655440000'; Accepted=$false},
            @{Text='{"id":"550e8400-e29b-41d4-a716-446655440000","ok":true}'; Accepted=$true; Stored='{"id":"550e8400-e29b-41d4-a716-446655440000","ok":true}'; Destination='Artifacts'},
            @{Text='{"api_key":"550e8400-e29b-41d4-a716-446655440000","ok":true}'; Accepted=$true; Stored='{"api_key":"[REDACTED]","ok":true}'; Destination='Artifacts'},
            @{Text='{"level":"INFO","count":1}'; Accepted=$true; Stored='{"level":"INFO","count":1}'; Destination='Artifacts'},
            @{Text='[{"result":"SYNC_COMPLETE","revision":"r20260921"},1]'; Accepted=$true; Stored='[{"result":"SYNC_COMPLETE","revision":"r20260921"},1]'; Destination='Artifacts'},
            @{Text=('Z9' + ('q' * 148)); Accepted=$false},
            @{Text=('Z9' + ('q' * 149)); Accepted=$true; Stored=('Z9' + ('q' * 149)); Destination='Password Boundary Test'},
            @{Text=('sk-' + ('q' * 180)); Accepted=$false},
            @{Text='{"password":"ExamplePass123!","ok":true}'; Accepted=$true; Stored='{"password":"[REDACTED]","ok":true}'; Destination='Artifacts'}
        )
        foreach ($case in $cases) {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($case.Text))
            $result = Invoke-IsolatedEval "setData(mimeText,fromBase64('$encoded'));setData(mimeOutputTab,'Password Boundary Test');var accepted=runAutomaticCommands();var destination=str(data(mimeOutputTab));var stored=null;if(accepted){saveData();tab(destination);stored=str(read(mimeText,0));}JSON.stringify({accepted:accepted,destination:destination,stored:stored})" | ConvertFrom-Json
            $result.accepted | Should Be $case.Accepted
            if ($case.Accepted) {
                $result.destination | Should Be $case.Destination
                $result.stored | Should Be $case.Stored
            } else {
                $result.stored | Should BeNullOrEmpty
            }
        }
    }

    It 'runs the native worker asynchronously with empty inherited input and saves only after a click and confirmation' {
        foreach ($exitCode in @(0, 2, 3)) {
            # Real action()/input()/File/info/hash/history APIs; only the GUI and
            # system clipboard are replaced with synthetic in-worker fixtures.
            $program = @'
var raw='{"message":"Synthetic example","api_key":"123e4567-e89b-42d3-a456-426614174000"}';
setData(mimeText,raw);setData(mimeHtml,'<b>'+raw+'</b>');setData(mimeOutputTab,'Native Redacted Test');
if(runAutomaticCommands())saveData();
var worker=str(settings('test_notice_code')).replace(/^copyq:\s*/,'');
settings('test_worker_result','');
var prelude='var cleanInput=str(input())==="" && str(data(mimeText))==="";var confirmations=0;var calls=[];var raw='+JSON.stringify(raw)+';'+
'var clipboard=function(format){return format==="?"?"text/plain\\n":raw;};'+
'var execute=function(){calls.push(Array.prototype.slice.call(arguments));return {exit_code:arguments[3]==="-close"?0:EXIT_CODE};};'+
'var dialog=function(){confirmations++;return true;};var notification=function(){};'+
'var old=config("clipboard_tab");config("clipboard_tab","Native Saved Test");tab("Native Saved Test");var mainBefore=size();tab("Artifacts");var before=size();';
var ending='tab("Native Saved Test");var mainAdded=size()-mainBefore;tab("Artifacts");settings("test_worker_result",JSON.stringify({cleanInput:cleanInput,confirmations:confirmations,added:size()-before,mainAdded:mainAdded,text:str(read(mimeText,0)),redacted:str(read(mimeText,confirmations?1:0)),calls:calls}));config("clipboard_tab",old);';
testRealAction('copyq:\n'+prelude+worker+'\n'+ending);
'SCHEDULED';
'@
            $program = $program.Replace('EXIT_CODE', [string]$exitCode)
            Invoke-IsolatedEval $program | Should Be 'SCHEDULED'
            $result = $null
            for ($attempt = 0; $attempt -lt 30; $attempt++) {
                $json = Invoke-IsolatedEval "str(settings('test_worker_result'))"
                if ($json) { $result = $json | ConvertFrom-Json; break }
                Start-Sleep -Milliseconds 100
            }
            $result | Should Not BeNullOrEmpty
            $result.cleanInput | Should Be $true
            $result.confirmations | Should Be ([int]($exitCode -eq 0))
            $result.added | Should Be ([int]($exitCode -eq 0))
            $result.mainAdded | Should Be 0
            if ($exitCode -eq 0) {
                $result.text | Should Be '{"message":"Synthetic example","api_key":"123e4567-e89b-42d3-a456-426614174000"}'
            }
            ($result.calls | ConvertTo-Json -Depth 5) | Should Not Match '123e4567'
            $result.redacted | Should Be '{"message":"Synthetic example","api_key":"[REDACTED]"}'
        }
    }

    It 'executes the one-time save action from both exports without a router dependency or persistent exemption' {
        $root = Split-Path -Parent $PSScriptRoot
        $alternative = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText((Join-Path $root 'commands\alternatives\secret-protection.ini'))))
        foreach ($selector in @("commands().filter(function(c){return c.internalId==='canonical.dispatcher';})[0]", "importCommands(str(fromBase64('$alternative')))[0]")) {
            $action = Invoke-IsolatedEval "var c=$selector;var captured;var ignored=false;var action=function(code){captured=code;};var ignore=function(){ignored=true;};var abort=function(){throw 'TEST_STOP';};setData(mimeText,'123e4567-e89b-42d3-a456-426614174000');try{eval(c.cmd.replace(/^copyq:\\s*/,''));}catch(e){if(e!=='TEST_STOP')throw e;}JSON.stringify({ignored:ignored,script:captured,digest:str(sha256sum('123e4567-e89b-42d3-a456-426614174000'))})" | ConvertFrom-Json
            $action.ignored | Should Be $true
            $action.digest | Should Match '^[0-9a-f]{64}$'
            $action.script | Should Not Match '123e4567-e89b-42d3-a456-426614174000'
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($action.script))
            $result = Invoke-IsolatedEval "var before=settings('frequent_usage_counts_v3');var oldTab=config('clipboard_tab');var target='Saved Once Test';config('clipboard_tab',target);tab(target);var beforeSize=size();var clipboard=function(format){return format==='?'?'text/plain\ntext/html\n':'123e4567-e89b-42d3-a456-426614174000';};var execute=function(){return {exit_code:0,stdout:'',stderr:''};};var confirmations=0;var dialog=function(){confirmations++;return true;};var notices=[];var notification=function(){notices.push(arguments[5]);};try{eval(str(fromBase64('$encoded')).replace(/^copyq:\\s*/,''));tab(target);JSON.stringify({added:size()-beforeSize,text:str(read(mimeText,0)),formats:Object.keys(getItem(0)),confirmations:confirmations,sameFrequency:before===settings('frequent_usage_counts_v3'),reason:notices[0]});}finally{config('clipboard_tab',oldTab);}" | ConvertFrom-Json
            $result.added | Should Be 1
            $result.text | Should Be '123e4567-e89b-42d3-a456-426614174000'
            $result.formats | Should Be @('text/plain')
            $result.confirmations | Should Be 1
            $result.sameFrequency | Should Be $true
            $result.reason | Should Be 'SECRET_SAVED_ONCE'

            foreach ($scenario in @('cancel', 'stale-before', 'stale-during', 'concealed-during')) {
                $result = Invoke-IsolatedEval "tab('Saved Once Test');var before=size();var scenario='$scenario';var value=scenario==='stale-before'?'OtherPass123!':'123e4567-e89b-42d3-a456-426614174000';var formats='text/plain\n';var clipboard=function(format){return format==='?'?formats:value;};var execute=function(){return {exit_code:0};};var dialog=function(){if(scenario==='stale-during')value='OtherPass123!';if(scenario==='concealed-during')formats+='Clipboard Viewer Ignore\n';return scenario==='cancel'?undefined:true;};var notification=function(){};var code=str(fromBase64('$encoded')).replace(/^copyq:\\s*/,'');var payload=JSON.parse(code.slice(code.lastIndexOf('nativeSecretNotice(')+19,-2));settings('secret_notification_current',payload.id);eval(code);tab('Saved Once Test');String(size()===before)"
                $result | Should Be 'true'
            }
        }
        # Copying the value again remains excluded and cannot remove the saved item.
        Invoke-IsolatedEval "tab('Saved Once Test');var before=size();setData(mimeText,'123e4567-e89b-42d3-a456-426614174000');var accepted=runAutomaticCommands();tab('Saved Once Test');String(!accepted && size()===before && str(read(mimeText,0))==='123e4567-e89b-42d3-a456-426614174000')" | Should Be 'true'
    }

    It 'stores only redacted MIME data and undo cannot recover the original secret' {
        $result = Invoke-IsolatedEval "var raw='Use ghp_' + Array(37).join('a') + ' for this request';var prior=settings('frequent_usage_counts_v3');setData(mimeText,raw);setData(mimeHtml,'<b>'+raw+'</b>');setData('text/rtf',raw);setData('application/x-private-test',raw);setData(mimeOutputTab,'Redaction Test');var accepted=runAutomaticCommands();if(accepted)saveData();tab('Redaction Test');var item=getItem(0);JSON.stringify({accepted:accepted,text:str(item[mimeText]),formats:Object.keys(item),frequencyUnchanged:prior===settings('frequent_usage_counts_v3'),leaked:Object.keys(item).some(function(k){return str(item[k]).indexOf('ghp_')>=0;})})" | ConvertFrom-Json
        $result.accepted | Should Be $true
        $result.text | Should Be 'Use [REDACTED] for this request'
        $result.formats | Should Be @('text/plain')
        $result.frequencyUnchanged | Should Be $true
        $result.leaked | Should Be $false
        Invoke-IsolatedEval "tab('Redaction Test');remove(0);tab('(trash)');str(read(mimeText,0))" | Should Be 'Use [REDACTED] for this request'
        Invoke-IsolatedEval "var c=commands().filter(function(x){return x.internalId==='canonical.undo-delete';})[0];eval(c.cmd.replace(/^copyq:\\s*/,''));'UNDONE'" | Should Be 'UNDONE'
        Invoke-IsolatedEval "tab('Redaction Test');var item=getItem(0);String(Object.keys(item).some(function(k){return str(item[k]).indexOf('ghp_')>=0;}))" | Should Be 'false'
    }

    It 'passes only sanitized text to later automatic commands and routes credential URLs safely' {
        Invoke-IsolatedEval "var cs=commands();cs.push({name:'Test Safe Later Copy',automatic:true,tab:'Safe Later Copy',input:''});setCommands(cs);'READY'" | Should Be 'READY'
        try {
            Invoke-IsolatedEval "setData(mimeText,'https://example.test/?access_token=synthetic&q=hello');setData(mimeHtml,'synthetic raw alternate');setData(mimeOutputTab,'Wrong URL Tab');if(runAutomaticCommands())saveData();tab('&URLs');str(read(mimeText,0))" | Should Be 'https://example.test/?access_token=[REDACTED]&q=hello'
            Invoke-IsolatedEval "tab('Safe Later Copy');str(read(mimeText,0))" | Should Be 'https://example.test/?access_token=[REDACTED]&q=hello'
            Invoke-IsolatedEval "tab('Safe Later Copy');String(Object.keys(getItem(0)).indexOf(mimeHtml))" | Should Be '-1'
        } finally {
            Invoke-IsolatedEval "setCommands(commands().filter(function(c){return c.name!=='Test Safe Later Copy';}));'RESTORED'" | Out-Null
        }
    }

    It 'runs standalone protection without routing or frequency indexing and rejects conflicting installs' {
        $root = Split-Path -Parent $PSScriptRoot
        $alternative = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText((Join-Path $root 'commands\alternatives\secret-protection.ini'))))
        # Native export preserves CopyQ RegExp fields; JSON stringification does not.
        $baseline = Invoke-IsolatedEval 'exportCommands(commands())'
        $baselineEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($baseline))
        try {
            Invoke-IsolatedEval "var transport=commands().filter(function(c){return c.name==='Test notification transport';});setCommands(importCommands(str(fromBase64('$alternative'))).concat(transport));'READY'" | Should Be 'READY'
            foreach ($sample in @('https://example.test/standalone', 'const plain = 1;', 'ordinary text')) {
                $sampleEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sample))
                $result = Invoke-IsolatedEval "var before=settings('frequent_usage_counts_v3');setData(mimeText,fromBase64('$sampleEncoded'));setData(mimeOutputTab,'Standalone Test');var accepted=runAutomaticCommands();if(accepted)saveData();tab('Standalone Test');JSON.stringify({text:str(read(mimeText,0)),destination:str(data(mimeOutputTab)),sameFrequency:before===settings('frequent_usage_counts_v3')})" | ConvertFrom-Json
                $result.text | Should Be $sample
                $result.destination | Should Be 'Standalone Test'
                $result.sameFrequency | Should Be $true
            }
            Invoke-IsolatedEval "setData(mimeText,'Use ghp_' + Array(37).join('a'));setData(mimeHtml,'alternate credential');setData(mimeOutputTab,'Standalone Test');if(runAutomaticCommands())saveData();tab('Standalone Test');str(read(mimeText,0))" | Should Be 'Use [REDACTED]'
            Invoke-IsolatedEval "tab('Standalone Test');String(Object.keys(getItem(0)).indexOf(mimeHtml))" | Should Be '-1'
            Invoke-IsolatedEval "setData(mimeText,'ghp_'+Array(37).join('b'));String(runAutomaticCommands())" | Should Be 'false'
            Invoke-IsolatedEval "setData('Clipboard Viewer Ignore','1');String(runAutomaticCommands())" | Should Be 'false'
            Invoke-IsolatedEval "setCommands(importCommands(str(fromBase64('$baselineEncoded'))).concat(importCommands(str(fromBase64('$alternative')))));'CONFLICT'" | Should Be 'CONFLICT'
            $conflict = Invoke-IsolatedEval "var before=settings('frequent_usage_counts_v3');setData(mimeText,'ordinary conflict test');setData(mimeOutputTab,'Conflict Must Stay Empty');var accepted=runAutomaticCommands();if(accepted)saveData();JSON.stringify({accepted:accepted,sameFrequency:before===settings('frequent_usage_counts_v3'),tabExists:tab().indexOf('Conflict Must Stay Empty')>=0})" | ConvertFrom-Json
            $conflict.accepted | Should Be $false
            $conflict.sameFrequency | Should Be $true
            $conflict.tabExists | Should Be $false
        } finally {
            Invoke-IsolatedEval "setCommands(importCommands(str(fromBase64('$baselineEncoded'))));'RESTORED'" | Out-Null
        }
    }

    It 'suppresses synthetic secrets before a later automatic copy-to-tab action can store them' {
        Invoke-IsolatedEval "var cs=commands();cs.push({name:'Test Later Copy',automatic:true,tab:'Must Stay Empty',input:''});setCommands(cs);'READY'" | Should Be 'READY'
        try {
            foreach ($extraFormat in @('text/html', 'image/png', 'application/x-copyq-owner')) {
                $result = Invoke-IsolatedEval "setData(mimeText,'ghp_abcdefghijklmnopqrstuvwxyz1234567890');setData('$extraFormat','synthetic');setData(mimeOutputTab,'Secret Fallback Test');var accepted=runAutomaticCommands();if(accepted)saveData();String(accepted)"
                $result | Should Be 'false'
            }
            Invoke-IsolatedEval "setData('image/png','synthetic');setData('Clipboard Viewer Ignore','1');String(runAutomaticCommands())" | Should Be 'false'
            Invoke-IsolatedEval "String(tab().indexOf('Must Stay Empty'))" | Should Be '-1'
            Invoke-IsolatedEval "String(tab().indexOf('Secret Fallback Test'))" | Should Be '-1'
        } finally {
            Invoke-IsolatedEval "setCommands(commands().filter(function(c){return c.name!=='Test Later Copy';}));'RESTORED'" | Out-Null
        }
    }
}
