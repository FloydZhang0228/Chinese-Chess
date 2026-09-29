# Windows 原生 PowerShell 入口。用法: scripts\build.ps1 <windows|android|web|all> [版本号]
# 需要已安装 Flutter 与 Visual Studio(C++ 桌面开发)。会转调 Git Bash 里的 build.sh。
param([Parameter(Mandatory = $true)][string]$Target, [string]$Version = "")
$ErrorActionPreference = "Stop"
$bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
if (-not $bash) { $bash = "$env:ProgramFiles\Git\bin\bash.exe" }
if (-not (Test-Path $bash)) { throw "未找到 bash, 请安装 Git for Windows" }
$sh = Join-Path $PSScriptRoot "build.sh"
& $bash $sh $Target $Version
exit $LASTEXITCODE
