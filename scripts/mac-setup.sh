#!/usr/bin/env bash
# Mac 에서 이 프로젝트를 처음 여는 스크립트.
#
#   git clone <repo> && cd wedding-plant-ios
#   ./scripts/mac-setup.sh
#
# .xcodeproj 는 저장소에 없다 (Windows 에서 만들 수 없어서 커밋하지 않는다).
# project.yml 로부터 XcodeGen 이 생성한다.

set -euo pipefail

cd "$(dirname "$0")/.."
echo "프로젝트: $(pwd)"
echo

# 1. Xcode 확인 -------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode 가 없습니다."
  echo "  App Store 에서 Xcode 를 설치한 뒤, 한 번 실행해 라이선스에 동의하세요."
  exit 1
fi

# Command Line Tools 만 설치된 상태면 시뮬레이터 빌드가 안 된다.
DEVELOPER_DIR_PATH=$(xcode-select -p)
if [[ "$DEVELOPER_DIR_PATH" == *"CommandLineTools"* ]]; then
  echo "Command Line Tools 만 선택돼 있습니다. 전체 Xcode 로 전환이 필요합니다:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Xcode: $(xcodebuild -version | head -1)"

# 2. Homebrew + XcodeGen ----------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  echo
  echo "Homebrew 가 없습니다. 먼저 설치하세요:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen 설치 중..."
  brew install xcodegen
fi
echo "XcodeGen: $(xcodegen --version)"

# 3. Core 패키지 테스트 -----------------------------------------------------
# Windows 와 달리 Mac 에서는 환경 준비가 필요 없다. 바로 돌아간다.
echo
echo "Core 테스트 실행 중..."
swift test --package-path Core

# 4. Xcode 프로젝트 생성 ----------------------------------------------------
echo
echo "Xcode 프로젝트 생성 중..."
xcodegen generate

echo
echo "완료. Xcode 를 엽니다."
echo
echo "  실행:        Xcode 에서 Cmd+R (시뮬레이터)"
echo "  UI 테스트:   Cmd+U"
echo "  실기기 설치: 아이폰을 USB 로 연결 → 상단 기기 선택 → Cmd+R"
echo "               (무료 Apple ID 로 가능. Signing & Capabilities 에서 팀 선택,"
echo "                Bundle ID 가 이미 쓰이는 값이면 뒤에 본인 것을 덧붙여 바꾼다)"
echo

open WeddingPlant.xcodeproj
