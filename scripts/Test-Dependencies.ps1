[CmdletBinding()]
param(
    [string] $LocalAppData = $env:LOCALAPPDATA,
    [string] $AppData = $env:APPDATA,
    [string] $ProgramFiles = $env:ProgramFiles,
    [switch] $AsJson
)

$ErrorActionPreference = 'Stop'

function Resolve-DependencyPath {
    param([string[]] $Names, [string[]] $Fallbacks)
    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    foreach ($candidate in $Fallbacks) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

$copyqPath = Resolve-DependencyPath -Names @('copyq.exe') -Fallbacks @((Join-Path $ProgramFiles 'CopyQ\copyq.exe'))
$markedPath = Resolve-DependencyPath -Names @('marked.cmd', 'marked') -Fallbacks @((Join-Path $AppData 'npm\marked.cmd'))
$pwshPath = Resolve-DependencyPath -Names @('pwsh.exe', 'pwsh') -Fallbacks @((Join-Path $ProgramFiles 'PowerShell\7\pwsh.exe'))
$tesseractPath = Resolve-DependencyPath -Names @('tesseract.exe', 'tesseract') -Fallbacks @((Join-Path $ProgramFiles 'Tesseract-OCR\tesseract.exe'))

$pythonCommand = Get-Command py.exe -ErrorAction SilentlyContinue
$pythonArguments = @('-3')
if (-not $pythonCommand) {
    $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
    $pythonArguments = @()
}
$pythonPath = if ($pythonCommand) { $pythonCommand.Source } else { $null }
$pygments = $false
if ($pythonPath) {
    & $pythonPath @pythonArguments -c 'import pygments' 2>$null
    $pygments = $LASTEXITCODE -eq 0
}

$languages = @()
if ($tesseractPath) {
    $languages = @(& $tesseractPath --list-langs 2>$null | Where-Object { $_ -and $_ -notmatch '^List of available languages' })
}

$moonlanderRoot = Join-Path $LocalAppData 'MoonlanderTextTools'
$moonlanderFiles = @('transformations.js', 'transaction.js', 'Moonlander.Reselect.exe')
$moonlanderReady = @($moonlanderFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $moonlanderRoot $_) -PathType Leaf) }).Count -eq 0

$result = [ordered]@{
    CopyQ = [ordered]@{ Available = [bool] $copyqPath; Path = $copyqPath }
    Marked = [ordered]@{ Available = [bool] $markedPath; Path = $markedPath }
    Python = [ordered]@{ Available = [bool] $pythonPath; Path = $pythonPath }
    Pygments = [ordered]@{ Available = $pygments }
    Tesseract = [ordered]@{ Available = [bool] $tesseractPath; Path = $tesseractPath }
    TesseractLanguages = [ordered]@{ English = $languages -contains 'eng'; Hebrew = $languages -contains 'heb' }
    PowerShell = [ordered]@{ Available = [bool] $pwshPath; Path = $pwshPath; Version = $PSVersionTable.PSVersion.ToString() }
    Moonlander = [ordered]@{ Available = $moonlanderReady; Root = $moonlanderRoot }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4 -Compress
} else {
    [pscustomobject] $result
}
