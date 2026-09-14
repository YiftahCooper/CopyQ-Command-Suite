$ErrorActionPreference = 'Stop'

Describe 'CopyQ bilingual OCR dependency' {
    BeforeAll {
        Add-Type -AssemblyName System.Drawing
        $tesseract = Get-Command tesseract.exe -ErrorAction SilentlyContinue
        $script:Tesseract = if ($tesseract) { $tesseract.Source } else { Join-Path $env:ProgramFiles 'Tesseract-OCR\tesseract.exe' }
        $script:FixtureRoot = [IO.Path]::GetFullPath((Join-Path $env:TEMP ('copyq-ocr-' + [guid]::NewGuid().ToString('N'))))
        $tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
        if (-not $script:FixtureRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "OCR_FIXTURE_PATH_OUTSIDE_TEMP: $script:FixtureRoot"
        }
        New-Item -ItemType Directory -Path $script:FixtureRoot | Out-Null

        function New-OcrFixture {
            param([string] $Name, [string[]] $Lines)

            $path = Join-Path $script:FixtureRoot "$Name.png"
            $bitmap = [Drawing.Bitmap]::new(1000, 320)
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $font = [Drawing.Font]::new('Arial', 54, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
            $brush = [Drawing.Brushes]::Black
            try {
                $graphics.Clear([Drawing.Color]::White)
                $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
                for ($i = 0; $i -lt $Lines.Count; $i += 1) {
                    $graphics.DrawString($Lines[$i], $font, $brush, 30, 25 + (105 * $i))
                }
                $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $font.Dispose()
                $graphics.Dispose()
                $bitmap.Dispose()
            }
            return $path
        }

        function Invoke-TesseractStdin {
            param([string] $Path)

            $start = [Diagnostics.ProcessStartInfo]::new()
            $start.FileName = $script:Tesseract
            foreach ($argument in @('stdin', 'stdout', '-l', 'eng+heb', '--oem', '3', '--psm', '6')) {
                [void] $start.ArgumentList.Add($argument)
            }
            $start.UseShellExecute = $false
            $start.CreateNoWindow = $true
            $start.RedirectStandardInput = $true
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            $process = [Diagnostics.Process]::new()
            $process.StartInfo = $start
            try {
                [void] $process.Start()
                $bytes = [IO.File]::ReadAllBytes($Path)
                $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
                $process.StandardInput.BaseStream.Close()
                $stdout = $process.StandardOutput.ReadToEnd()
                $stderr = $process.StandardError.ReadToEnd()
                $process.WaitForExit()
                return [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
            } finally {
                $process.Dispose()
            }
        }

        $script:EnglishFixture = New-OcrFixture -Name 'english' -Lines @('HELLO 123')
        $script:HebrewFixture = New-OcrFixture -Name 'hebrew' -Lines @('שלום עולם')
        $script:MixedFixture = New-OcrFixture -Name 'mixed' -Lines @('HELLO 123', 'שלום עולם')
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:FixtureRoot) {
            Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force
        }
    }

    It 'recognizes English from PNG bytes on standard input' {
        $result = Invoke-TesseractStdin -Path $script:EnglishFixture
        $result.ExitCode | Should Be 0
        $result.StdOut | Should Match 'HELLO'
    }

    It 'recognizes Hebrew from PNG bytes on standard input' {
        $result = Invoke-TesseractStdin -Path $script:HebrewFixture
        $result.ExitCode | Should Be 0
        $result.StdOut | Should Match '[א-ת]'
    }

    It 'recognizes both scripts without asking for a language' {
        $result = Invoke-TesseractStdin -Path $script:MixedFixture
        $result.ExitCode | Should Be 0
        $result.StdOut | Should Match 'HELLO'
        $result.StdOut | Should Match '[א-ת]'
    }

    It 'runs the exported CopyQ command when Tesseract is installed but absent from PATH' {
        Import-Module (Join-Path $PSScriptRoot '../modules/CopyQ.Setup.psm1') -Force
        $session='cqoc-'+[guid]::NewGuid().ToString('N').Substring(0,8)
        $priorPath=$env:PATH; $priorSettings=$env:COPYQ_SETTINGS_PATH; $priorItems=$env:COPYQ_ITEM_DATA_PATH
        $env:COPYQ_SETTINGS_PATH=Join-Path $FixtureRoot 'settings'
        $env:COPYQ_ITEM_DATA_PATH=Join-Path $FixtureRoot 'items'
        $context=New-CopyQSetupContext -Root (Split-Path $PSScriptRoot) -Session $session -StateRoot (Join-Path $FixtureRoot 'state')
        $env:PATH=''
        $server=$null
        try {
            $server=Start-Process $context.Executable -ArgumentList @('-s',$session) -WindowStyle Hidden -PassThru
            Start-Sleep -Milliseconds 500
            $png=[Convert]::ToBase64String([IO.File]::ReadAllBytes($MixedFixture))
            $ini=[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../commands/individual/copy-text-in-image.ini')))
            # Run native selection/data handling and execute(), intercepting ONLY
            # the final clipboard write so acceptance never changes the user's clipboard.
            $program="setData('image/png',fromBase64('$png'));var source=importCommands(str(fromBase64('$ini')))[0].cmd.replace(/^copyq:\s*/, '');" + @'
if(source.indexOf('copy(mimeText, text);')<0)throw Error('OCR_CLIPBOARD_BOUNDARY_MISSING');
source=source.replace('copy(mimeText, text);', "settings('ocr_test_result', text);");
eval(source);
str(settings('ocr_test_result'));
'@
            $result=Invoke-CopyQSetupProcess $context @('eval','-') $program -TimeoutSeconds 5
            $result | Should Match 'HELLO'
            $result | Should Match '[א-ת]'
        } finally {
            if($server){try{Invoke-CopyQSetupProcess $context @('exit') | Out-Null}finally{[void]$server.WaitForExit(5000)}}
            $env:PATH=$priorPath; $env:COPYQ_SETTINGS_PATH=$priorSettings; $env:COPYQ_ITEM_DATA_PATH=$priorItems
        }
    }
}
