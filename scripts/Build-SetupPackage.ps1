#Requires -Version 7.2
[CmdletBinding()]
param([string] $OutputDirectory=(Join-Path (Split-Path -Parent $PSScriptRoot) 'dist'))
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'modules/CopyQ.Setup.psm1') -Force
$manifest=Get-Content (Join-Path $root 'manifest/public-commands.json') -Raw | ConvertFrom-Json
$paths=@(Get-Content (Join-Path $root 'PUBLIC-FILES.txt'))
if (@(Compare-Object $paths @($manifest.publicFiles)).Count -or $paths.Count -ne @($paths | Sort-Object -Unique).Count) {throw 'PUBLIC_INVENTORY_MISMATCH'}
$package=Get-CopyQSetupPackage $root
$destination=[IO.Path]::GetFullPath($OutputDirectory);[void][IO.Directory]::CreateDirectory($destination)
$temporary=Join-Path $destination ('setup-' + [guid]::NewGuid().ToString('N') + '.partial')
$stream=[IO.File]::Open($temporary,[IO.FileMode]::CreateNew)
try {
    $zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        foreach ($relative in ($paths | Sort-Object -Culture '')) {
            $source=Resolve-CopyQPackagePath $root $relative
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {throw 'PUBLIC_FILE_MISSING'}
            $entry=$zip.CreateEntry($relative.Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime=[DateTimeOffset]::new(2020,1,1,0,0,0,[TimeSpan]::Zero)
            $target=$entry.Open()
            try {
                $bytes=[IO.File]::ReadAllBytes($source);$target.Write($bytes,0,$bytes.Length)
            } finally {$target.Dispose()}
        }
    } finally {$zip.Dispose()}
} finally {$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
$output=Join-Path $destination ('CopyQ-Setup-' + $hash.Substring(0,12) + '.zip')
if(Test-Path -LiteralPath $output){
    if((Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant() -ne $hash){throw 'EXISTING_PACKAGE_MISMATCH'}
    [IO.File]::Delete($temporary)
}else{[IO.File]::Move($temporary,$output)}
[IO.File]::WriteAllText($output+'.sha256',$hash+'  '+[IO.Path]::GetFileName($output)+"`n",[Text.UTF8Encoding]::new($false))
[pscustomobject]@{Path=$output;Sha256=$hash;Files=$paths.Count;CommandPackageDigest=$package.Digest}
