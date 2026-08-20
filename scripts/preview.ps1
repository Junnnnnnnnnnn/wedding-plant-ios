# CI 가 만든 앱 화면(스크린샷 + 동영상)을 내려받아 폴더를 연다.
#
# Windows 에서는 시뮬레이터를 띄울 수 없으므로 이게 화면을 보는 방법이다.
#
# 사용법:
#   .\scripts\preview.ps1              # 가장 최근 성공한 실행에서 받기
#   .\scripts\preview.ps1 -Watch       # 지금 도는 CI 가 끝날 때까지 기다렸다가 받기
#   .\scripts\preview.ps1 -RunId 123   # 특정 실행에서 받기

[CmdletBinding()]
param(
    [string]$RunId,
    [switch]$Watch
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "gh CLI 가 없습니다. https://cli.github.com"
}

if (-not $RunId) {
    if ($Watch) {
        # 진행 중인 실행이 있으면 그것을, 없으면 최근 실행을 본다.
        $RunId = gh run list --limit 1 --json databaseId --jq ".[0].databaseId"
        Write-Host "CI 실행 $RunId 를 기다립니다 (10~15분)..." -ForegroundColor Cyan
        gh run watch $RunId --interval 30 | Out-Null
    } else {
        # 아티팩트는 성공한 실행에만 확실히 있다.
        $RunId = gh run list --limit 1 --status success --json databaseId --jq ".[0].databaseId"
    }
}

if (-not $RunId) { throw "받아올 CI 실행을 찾지 못했습니다." }

$out = Join-Path $repoRoot "preview"
Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $out | Out-Null

Write-Host "실행 $RunId 에서 아티팩트를 받는 중..." -ForegroundColor Cyan
gh run download $RunId --name app-preview --dir $out
if ($LASTEXITCODE -ne 0) { throw "아티팩트를 받지 못했습니다. 실행이 아직 안 끝났을 수 있습니다." }

# 스크린샷 파일명이 UUID 라서 manifest 로 사람이 읽을 이름을 붙인다.
$shots = Join-Path $out "screenshots"
$manifest = Join-Path $shots "manifest.json"
if (Test-Path $manifest) {
    $entries = Get-Content $manifest -Raw | ConvertFrom-Json
    foreach ($entry in $entries) {
        foreach ($a in $entry.attachments) {
            $src = Join-Path $shots $a.exportedFileName
            $name = ($a.suggestedHumanReadableName -split '_')[0]
            if ((Test-Path $src) -and $name) {
                Copy-Item $src (Join-Path $shots "$name.png") -Force
            }
        }
    }
    # UUID 원본은 지워서 폴더를 깔끔하게 둔다.
    Get-ChildItem $shots -Filter *.png |
        Where-Object { $_.BaseName -match '^[0-9A-F]{8}-' } |
        Remove-Item -Force
}

Write-Host ""
Write-Host "받은 화면:" -ForegroundColor Green
Get-ChildItem $shots -Filter *.png -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object { "  $($_.Name)" }

$video = Join-Path $out "simulator.mp4"
if (Test-Path $video) {
    Write-Host ""
    Write-Host "  simulator.mp4  (전체 조작 과정 녹화)" -ForegroundColor Green
}

Write-Host ""
Invoke-Item $shots
