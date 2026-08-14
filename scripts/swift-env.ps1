# Swift on Windows 개발 환경 초기화.
#
# Swift 툴체인은 MSVC 링커(link.exe)와 Windows SDK를 사용하는데, 일반 PowerShell 창에는
# 이들이 PATH에 없다. 그래서 vcvars64.bat 를 불러와 환경변수를 현재 세션으로 가져온다.
# (안 하면 `swift build` 가 "toolchain is invalid: could not find CLI tool `link`" 로 실패한다.)
#
# 사용법:
#   . .\scripts\swift-env.ps1      # 점(dot) 소싱해야 현재 세션에 반영된다
#   swift build
#   swift test

$ErrorActionPreference = "Stop"

# 1) 시스템/사용자 환경변수를 통째로 다시 읽어 온다.
#    설치 직후 이미 열려 있던 터미널은 PATH 뿐 아니라 SDKROOT 도 못 받는다.
#    SDKROOT 가 없으면 "unable to load standard library for target x86_64-unknown-windows-msvc" 로 실패한다.
foreach ($scope in @("Machine", "User")) {
    foreach ($entry in [System.Environment]::GetEnvironmentVariables($scope).GetEnumerator()) {
        if ($entry.Key -eq "Path") { continue }   # PATH 는 아래에서 합쳐서 처리
        Set-Item -Path "env:$($entry.Key)" -Value $entry.Value
    }
}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

# 2) vcvars64.bat 위치 탐색
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe 를 찾을 수 없습니다. Visual Studio 2022 Build Tools 를 먼저 설치하세요."
}

$vsPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -format value -property installationPath
if (-not $vsPath) {
    throw "C++ 빌드 도구가 설치되어 있지 않습니다. winget install --id Microsoft.VisualStudio.2022.BuildTools ..."
}

$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) {
    throw "vcvars64.bat 를 찾을 수 없습니다: $vcvars"
}

# 3) vcvars64.bat 를 cmd 에서 실행한 뒤 결과 환경변수를 현재 PowerShell 세션으로 복사
cmd /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        Set-Item -Path "env:$($matches[1])" -Value $matches[2]
    }
}

$swift = Get-Command swift -ErrorAction SilentlyContinue
if (-not $swift) {
    throw "swift 를 찾을 수 없습니다. winget install --id Swift.Toolchain -e 로 설치하세요."
}

Write-Host "Swift 환경 준비 완료" -ForegroundColor Green
& swift --version
