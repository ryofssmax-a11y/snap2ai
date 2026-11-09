# Snap2AI ビルドスクリプト（Windows PowerShell 5.1 以降）
# AutoHotkey v2 と Ahk2Exe（どちらも公式の zip、インストール不要）を tools\ に取ってきて snap2ai.exe を作り、
# 配布用の zip（dist\snap2ai-v<版>.zip）にまとめます。
param([string]$Version = "1.0.0")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$tools = Join-Path $root "tools"
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $tools, $dist | Out-Null
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$ProgressPreference = 'SilentlyContinue'

if (-not (Test-Path "$tools\ahk\AutoHotkey64.exe")) {
    Invoke-WebRequest "https://www.autohotkey.com/download/ahk-v2.zip" -OutFile "$tools\ahk-v2.zip" -UseBasicParsing
    Expand-Archive -Force "$tools\ahk-v2.zip" "$tools\ahk"
}
if (-not (Test-Path "$tools\ahk2exe\Ahk2Exe.exe")) {
    $r = Invoke-RestMethod "https://api.github.com/repos/AutoHotkey/Ahk2Exe/releases/latest" -UseBasicParsing
    $a = $r.assets | Where-Object name -like '*.zip' | Select-Object -First 1
    Invoke-WebRequest $a.browser_download_url -OutFile "$tools\ahk2exe.zip" -UseBasicParsing
    Expand-Archive -Force "$tools\ahk2exe.zip" "$tools\ahk2exe"
}

$p = Start-Process "$tools\ahk\AutoHotkey64.exe" -ArgumentList '/ErrorStdOut=UTF-8', '/validate', "`"$root\snap2ai.ahk`"" -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { throw "snap2ai.ahk に構文エラーがあります" }

$out = Join-Path $dist "snap2ai.exe"
$p = Start-Process "$tools\ahk2exe\Ahk2Exe.exe" -ArgumentList '/in', "`"$root\snap2ai.ahk`"", '/out', "`"$out`"", '/base', "`"$tools\ahk\AutoHotkey64.exe`"", '/silent', 'verbose' -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { throw "Ahk2Exe のコンパイルに失敗しました" }

$stage = Join-Path $dist "snap2ai"
Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$stage\browser-ext" | Out-Null
Copy-Item $out, "$root\README.md", "$root\LICENSE" $stage
Copy-Item -Recurse "$root\browser-ext\chrome", "$root\browser-ext\firefox" "$stage\browser-ext"
$zip = Join-Path $dist "snap2ai-v$Version.zip"
Remove-Item $zip -ErrorAction SilentlyContinue
# Compress-Archive（PowerShell 5.1）は区切りが \ になるため、/ 区切りで自前に作る
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$fs = [System.IO.File]::Open($zip, 'CreateNew')
$za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
Get-ChildItem -Recurse -File $stage | ForEach-Object {
    $name = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $_.FullName, "snap2ai/$name") | Out-Null
}
$za.Dispose(); $fs.Dispose()
Write-Host "OK: $zip"
