# TestFlight 배포용 코드 서명 준비 (Mac 없이, Windows 에서).
#
# Apple 개발자 포털에서 직접 해야 하는 단계가 중간에 있어서 3단계로 나눠져 있다.
#
#   .\scripts\setup-signing.ps1 -Step csr     -Email <애플ID이메일> -CommonName "<이름 또는 조직명>"
#     → signing\ios_dist.csr 생성. 이걸 개발자 포털에 업로드해 distribution.cer 를 받는다.
#
#   .\scripts\setup-signing.ps1 -Step p12     -Password "강한비밀번호"
#     → 내려받은 signing\distribution.cer 를 signing\distribution.p12 로 변환.
#
#   .\scripts\setup-signing.ps1 -Step secrets -Password "위와같은비밀번호" `
#         -AscKeyId ABCD123456 -AscIssuerId 69a6de00-...
#     → GitHub Secrets 6개를 자동 등록 (gh CLI 로그인 필요).
#
# 생성물은 전부 signing\ 아래에 떨어지고, .gitignore 로 커밋이 차단된다.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("csr", "p12", "secrets")]
    [string]$Step,

    [string]$Email,
    [string]$CommonName,
    [string]$Country = "KR",
    [string]$Password,
    [string]$AscKeyId,
    [string]$AscIssuerId
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$signing = Join-Path $repoRoot "signing"
New-Item -ItemType Directory -Force -Path $signing | Out-Null

# Git 에 딸려오는 openssl 을 쓴다.
$openssl = (Get-Command openssl -ErrorAction SilentlyContinue).Source
if (-not $openssl) {
    $candidate = "C:\Program Files\Git\mingw64\bin\openssl.exe"
    if (Test-Path $candidate) { $openssl = $candidate }
}
if (-not $openssl) {
    throw "openssl 을 찾을 수 없습니다. Git for Windows 를 설치하거나 openssl 을 PATH 에 추가하세요."
}

function Set-GhSecret {
    param([string]$Name, [string]$Value)
    $tmp = New-TemporaryFile
    try {
        # -NoNewline: 끝의 개행이 시크릿 값에 섞이면 서명·업로드가 실패한다.
        Set-Content -Path $tmp -Value $Value -NoNewline -Encoding ascii
        Get-Content -Raw $tmp | gh secret set $Name
        if ($LASTEXITCODE -ne 0) { throw "gh secret set $Name 실패" }
        Write-Host "  등록됨: $Name" -ForegroundColor Green
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

switch ($Step) {

    "csr" {
        if (-not $Email -or -not $CommonName) {
            throw "-Email 과 -CommonName 이 필요합니다. 예: -Email you@example.com -CommonName 'Your Name'"
        }

        $key = Join-Path $signing "ios_dist.key"
        $csr = Join-Path $signing "ios_dist.csr"

        & $openssl genrsa -out $key 2048
        & $openssl req -new -key $key -out $csr -subj "/emailAddress=$Email/CN=$CommonName/C=$Country"
        if ($LASTEXITCODE -ne 0) { throw "CSR 생성 실패" }

        Write-Host ""
        Write-Host "CSR 생성 완료: $csr" -ForegroundColor Green
        Write-Host ""
        Write-Host "다음 단계 (브라우저에서):" -ForegroundColor Cyan
        Write-Host "  1. https://developer.apple.com/account/resources/certificates/list"
        Write-Host "  2. '+' -> Apple Distribution -> 위 .csr 업로드 -> distribution.cer 다운로드"
        Write-Host "  3. 내려받은 파일을 여기에 두세요: $signing\distribution.cer"
        Write-Host "  4. 그다음: .\scripts\setup-signing.ps1 -Step p12 -Password '비밀번호'"
    }

    "p12" {
        if (-not $Password) { throw "-Password 가 필요합니다." }

        $key = Join-Path $signing "ios_dist.key"
        $cer = Join-Path $signing "distribution.cer"
        $pem = Join-Path $signing "distribution.pem"
        $p12 = Join-Path $signing "distribution.p12"

        if (-not (Test-Path $key)) { throw "$key 가 없습니다. -Step csr 을 먼저 실행하세요." }
        if (-not (Test-Path $cer)) { throw "$cer 가 없습니다. 개발자 포털에서 인증서를 내려받아 여기에 두세요." }

        & $openssl x509 -inform DER -in $cer -out $pem
        if ($LASTEXITCODE -ne 0) { throw "인증서 변환 실패 (.cer -> .pem)" }

        # -legacy: macOS keychain 이 읽을 수 있는 암호화 방식으로 내보낸다.
        # OpenSSL 3.x 기본값으로 만들면 CI 의 security import 에서 실패하는 경우가 있다.
        & $openssl pkcs12 -export -inkey $key -in $pem -out $p12 -passout "pass:$Password" -legacy
        if ($LASTEXITCODE -ne 0) {
            Write-Host "-legacy 실패. 기본 방식으로 재시도합니다." -ForegroundColor Yellow
            & $openssl pkcs12 -export -inkey $key -in $pem -out $p12 -passout "pass:$Password"
            if ($LASTEXITCODE -ne 0) { throw ".p12 생성 실패" }
        }

        Write-Host ""
        Write-Host ".p12 생성 완료: $p12" -ForegroundColor Green
        Write-Host ""
        Write-Host "다음 단계 (브라우저에서):" -ForegroundColor Cyan
        Write-Host "  1. Identifiers 에 Bundle ID 등록: com.zipshowkorea.weddingplant"
        Write-Host "  2. Profiles -> '+' -> App Store Connect -> 프로파일 생성 -> 다운로드"
        Write-Host "     저장 위치: $signing\profile.mobileprovision"
        Write-Host "  3. App Store Connect -> Integrations -> Keys 에서 API 키(.p8) 발급"
        Write-Host "     저장 위치: $signing\AuthKey_XXXXXXXX.p8   (재다운로드 불가! 꼭 보관)"
        Write-Host "  4. 그다음: .\scripts\setup-signing.ps1 -Step secrets -Password '비밀번호' -AscKeyId XXX -AscIssuerId YYY"
    }

    "secrets" {
        if (-not $Password) { throw "-Password 가 필요합니다 (.p12 만들 때 쓴 것)." }
        if (-not $AscKeyId -or -not $AscIssuerId) { throw "-AscKeyId 와 -AscIssuerId 가 필요합니다." }

        $p12 = Join-Path $signing "distribution.p12"
        $profile = Join-Path $signing "profile.mobileprovision"
        $p8 = Join-Path $signing "AuthKey_$AscKeyId.p8"

        foreach ($f in @($p12, $profile, $p8)) {
            if (-not (Test-Path $f)) { throw "$f 가 없습니다." }
        }

        gh auth status | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "gh 에 로그인되어 있지 않습니다. gh auth login 을 먼저 실행하세요." }

        Write-Host "GitHub Secrets 등록 중..." -ForegroundColor Cyan
        Set-GhSecret "IOS_DIST_P12_BASE64"          ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p12)))
        Set-GhSecret "IOS_DIST_P12_PASSWORD"        $Password
        Set-GhSecret "IOS_PROVISION_PROFILE_BASE64" ([Convert]::ToBase64String([IO.File]::ReadAllBytes($profile)))
        Set-GhSecret "ASC_KEY_ID"                   $AscKeyId
        Set-GhSecret "ASC_ISSUER_ID"                $AscIssuerId
        Set-GhSecret "ASC_KEY_P8"                   ([IO.File]::ReadAllText($p8))

        Write-Host ""
        Write-Host "완료. 이제 TestFlight 빌드를 돌릴 수 있습니다:" -ForegroundColor Green
        Write-Host "  gh workflow run device.yml -f mode=testflight"
    }
}
