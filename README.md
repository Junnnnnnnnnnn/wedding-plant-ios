# wedding-plant-ios

`wedding-plant` 웹앱(Next.js)의 iOS 네이티브(Swift) 포팅.

개발 머신이 **Windows** 이므로, UI가 아닌 코드는 전부 `Core/` SwiftPM 패키지에 두어
Windows에서 직접 빌드·테스트하고, SwiftUI 화면과 코드 서명은 macOS CI에서 처리한다.

```
Core/       SwiftPM 패키지 — Windows에서 swift build / swift test 가능
App/        SwiftUI 화면 + 플랫폼 의존 구현 (macOS CI에서만 빌드)
project.yml XcodeGen 설정 — .xcodeproj는 CI에서 생성 (커밋 안 함)
scripts/    Windows 개발 편의 스크립트
docs/       환경 구성·테스트·배포 가이드
```

- **현재 상태·다음 할 일: [`docs/STATUS.md`](docs/STATUS.md)**
- **Mac 에서 구동하기: [`docs/RUN_ON_MAC.md`](docs/RUN_ON_MAC.md)**
- 아이폰에 설치하기 (Mac 없이): [`docs/INSTALL_ON_IPHONE.md`](docs/INSTALL_ON_IPHONE.md)
- 앱 화면 보는 법 (CI 스크린샷·동영상): [`docs/VIEW_THE_APP.md`](docs/VIEW_THE_APP.md)
- 테스트 실행·작성 방법: [`docs/TESTING.md`](docs/TESTING.md)
- 전체 전략·TestFlight 파이프라인·인증서 발급: [`docs/IOS_DEV_ON_WINDOWS.md`](docs/IOS_DEV_ON_WINDOWS.md)
- Core 패키지 설계 규칙: [`Core/README.md`](Core/README.md)

---

## Windows 개발 환경 구성

### 1. 사전 요구: Visual Studio Build Tools

Swift Windows 툴체인은 MSVC 링커와 Windows SDK를 사용한다. 먼저 설치해야 한다.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e `
  --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

용량이 크다(수 GB). 설치 후 **재부팅 또는 새 터미널** 필요.

### 2. Swift 툴체인

```powershell
winget install --id Swift.Toolchain -e
```

설치 후 새 PowerShell 창에서 확인:

```powershell
swift --version
```

### 3. Core 빌드 · 테스트

**새 PowerShell 창마다 환경 스크립트를 점(dot) 소싱해야 한다.** MSVC 링커(`link.exe`)와
`SDKROOT` 가 기본 PowerShell 세션에는 없기 때문이다.

```powershell
.\scripts\test.ps1                    # 전체 테스트 (환경 준비까지 알아서 함)
.\scripts\test.ps1 KstDateTests       # 특정 스위트만
.\scripts\test.ps1 -Build             # 빌드만
```

`swift` 명령을 직접 쓰려면 새 창마다 환경을 먼저 불러온다.

```powershell
. .\scripts\swift-env.ps1     # 점 하나 + 공백 필수
cd Core
swift build
swift test
```

빌드 중 나오는 `unable to create symbolic link at ...\.build\debug` 경고는 무시해도 된다
(Windows 심볼릭 링크 권한 문제이며 빌드는 정상). 또한 `swift build 2>&1` 로 실행하면 경고만
있어도 PowerShell이 exit 1로 보이게 하므로, `2>&1` 없이 `$LASTEXITCODE` 로 판단할 것.

### 4. 에디터 (선택)

VS Code + `swiftlang.swift-vscode` 확장 — LSP 자동완성, 테스트 러너, 디버깅.

---

## 현재 상태

- [x] `Core/WPModels` — 백엔드 DTO, `APIEnvelope`
- [x] `Core/WPUtils` — KST 날짜, JWT 디코더
- [x] `Core/WPNetworking` — `HTTPTransport`, `APIClient`, `Endpoint` 카탈로그, `MockTransport`
- [x] `Core/WPDomain` — 로그인 후 라우팅, 플랜 완성도, 게스트 마이그레이션, 예산 요약
- [x] Windows 환경 구성 (VS Build Tools 17.14 + Swift 6.3.3) — `swift test` 82/82 통과
- [x] `project.yml` (XcodeGen) + SwiftUI 앱 스켈레톤 (온보딩·설정·메인·참여플랜·설정탭)
- [x] GitHub Actions 시뮬레이터 캡처 파이프라인 (Apple 계정 불필요)
- [ ] **CI 첫 실행 — SwiftUI 컴파일 검증 (Windows에서는 불가)**
- [ ] Apple Developer Program 가입
- [ ] TestFlight 업로드 job 추가 (서명 + 아카이브)
- [ ] 나머지 화면 (`/add-plen`, `/budget-detail`, `/chat`, `/share`, `/calendar`)
- [ ] 카카오 로그인 실연동 (Kakao iOS SDK)
- [ ] 백엔드: APNs 디바이스 토큰 등록 API (iOS는 SSE를 백그라운드에서 유지 못 함)

## 백엔드

모든 데이터 API는 `${API_BASE_URL}/plan/...`. 응답은 일관되게 `{ result: Bool, data: ... }`.
엔드포인트 전체 목록은 `Core/Sources/WPNetworking/Endpoint.swift` 참고.
