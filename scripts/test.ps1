# Core 패키지 테스트 실행기.
#
# 환경 준비(vcvars + SDKROOT)를 알아서 하고, PowerShell이 경고를 에러로 둔갑시키는 문제를
# 피해 실제 종료 코드로 성공/실패를 판정한다.
#
# 사용법:
#   .\scripts\test.ps1                    # 전체 실행
#   .\scripts\test.ps1 KstDateTests       # 특정 스위트만
#   .\scripts\test.ps1 KstDateTests/test_days_until   # 특정 테스트 하나만
#   .\scripts\test.ps1 -List              # 테스트 목록만 출력
#   .\scripts\test.ps1 -Build             # 테스트 없이 빌드만

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Filter,

    [switch]$List,

    [switch]$Build
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "swift-env.ps1")

Push-Location (Join-Path $repoRoot "Core")
try {
    if ($List) {
        swift test list
    } elseif ($Build) {
        swift build
    } elseif ($Filter) {
        swift test --filter $Filter
    } else {
        swift test
    }
    $code = $LASTEXITCODE

    Write-Host ""
    if ($code -eq 0) {
        Write-Host "PASS (exit $code)" -ForegroundColor Green
    } else {
        Write-Host "FAIL (exit $code)" -ForegroundColor Red
    }
    exit $code
} finally {
    Pop-Location
}
