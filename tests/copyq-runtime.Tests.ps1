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
                if ($null -ne $InputText) {
                    $process.StandardInput.Write($InputText)
                    $process.StandardInput.Close()
                }
                $stdout = $process.StandardOutput.ReadToEnd()
                $stderr = $process.StandardError.ReadToEnd()
                $process.WaitForExit()
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
        Invoke-IsolatedEval "var imported=importCommands(str(fromBase64('$encoded')));setCommands(imported);String(commands().filter(function(c){return /^(?:canonical|moonlander)\./.test(c.internalId||'');}).length)" | Should Be '18'
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
            Invoke-IsolatedEval "tab('Dispatcher Input');var dispatcher=commands().filter(function(x){return x.internalId==='canonical.dispatcher';})[0];action(0,dispatcher.cmd);'STARTED'" | Should Be 'STARTED'
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
}
