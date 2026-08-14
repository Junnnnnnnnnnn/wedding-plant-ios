# Windows에서 iOS 네이티브(Swift) 개발·테스트 가이드

대상: `wedding-plant` Next.js 웹앱을 iOS 네이티브 앱으로 포팅
작성 기준일: 2026-08-14

---

## 0. 먼저 알아야 할 제약 (냉정한 사실)

| 항목 | Windows에서 가능? |
| --- | --- |
| Swift 언어 컴파일 / 유닛테스트 | 가능 (swift.org Windows 툴체인) |
| Foundation (JSON, Date, String 등) | 대부분 가능 (`swift-corelibs-foundation`) |
| SwiftUI / UIKit 빌드 | **불가능** |
| iOS 시뮬레이터 실행 | **불가능** |
| `.xcodeproj` 생성 / Xcode | **불가능** (macOS 전용) |
| `.ipa` 아카이브 / 코드 서명 | **불가능** (로컬에서는) |
| 인증서·프로비저닝 프로파일 발급 | **가능** (openssl + Apple 개발자 웹 포털) |
| TestFlight 업로드 | **가능** (CI의 macOS 러너 경유) |

결론: **Windows 로컬 = 로직 개발 + 유닛테스트**, **macOS(CI 또는 클라우드 맥) = UI 빌드 + 서명 + 배포**로 역할을 쪼개야 합니다.
그리고 **실물 iPhone 1대는 필수**입니다 (TestFlight 설치용). 이게 없으면 사실상 검증 불가.

---

## 1. 환경 선택지 비교

### A. GitHub Actions macOS 러너 + TestFlight  (Mac 0대, 추천 시작점)

- 비용: 개인 저장소는 무료 분(minutes)이 macOS에서 10배로 소진됨 → Free 플랜 2,000분 = 실질 macOS 약 200분/월.
  빌드 1회 8~12분 기준 **월 15~20회 정도 무료**, 초과분은 분당 과금(대략 $0.08~0.16/분, 요금은 GitHub 문서에서 확인).
- 장점: Mac 구매 0원. 서명·업로드 완전 자동화 가능.
- 단점: **피드백 루프가 느림**(1회 확인에 15~25분). UI 미세 조정에는 고통스러움.
- 보완: CI에서 시뮬레이터를 띄워 `xcrun simctl io ... screenshot` 또는 XCUITest 스냅샷을 찍어 **아티팩트로 다운로드** → Windows에서 눈으로 확인. UI 검증 루프를 어느 정도 살릴 수 있음.

### B. 클라우드 Mac 대여

| 서비스 | 대략 비용 | 비고 |
| --- | --- | --- |
| MacinCloud (Pay-as-you-go / Dedicated) | 월 $25~50 | RDP로 Xcode 직접 사용. 가장 진입 쉬움 |
| Scaleway Mac mini (M1/M2/M4) | 시간당 과금이지만 **최소 24시간 청구** | VNC. 장기 임대 시 저렴 |
| AWS EC2 Mac | 시간당, **최소 24시간 청구** | 비쌈. 기업용 |
| MacStadium | 월 $99~ | 안정적, CI 용도 |

장점: 시뮬레이터 인터랙티브 사용 가능 → 실제 개발 속도 확보.
단점: 네트워크 지연으로 Xcode가 답답함. 월 고정비.

### C. 중고 Mac mini (M1/M2) 구매 — **진지하게 갈 거면 최선**

- M1 8GB/256GB 중고 대략 40~70만원. 클라우드 Mac 12~18개월치와 비슷.
- Windows에서 원격 데스크톱으로 붙여 쓰면 됨. 시뮬레이터·Xcode·디버깅 전부 정상.
- iOS 앱을 계속 유지보수할 거라면 **투자 대비 회수가 가장 빠름**.

### D. Xcode Cloud

- Apple Developer Program 가입 시 월 25 compute hours 무료. 서명이 자동이라 편함.
- 단, **최초 워크플로 생성 시 Xcode(=Mac)가 한 번 필요**. Mac이 0대면 시작 자체가 막힘.

### E. Hackintosh / macOS VM

- Apple EULA 위반이고 불안정. TestFlight/서명 이슈도 잦음. **비권장**.

---

## 2. 권장 아키텍처: Core / App 분리

Windows에서 최대한 많은 코드를 실제로 컴파일·테스트하려면, **UI가 아닌 것 전부를 SwiftPM 패키지로 빼야** 합니다.

```
wedding-plant-ios/
├─ Core/                        # SwiftPM 패키지 — Windows에서 swift build / swift test 됨
│  ├─ Package.swift
│  ├─ Sources/
│  │  ├─ WPModels/              # Plan, Schedule, ChatMessage, User ... (Codable)
│  │  ├─ WPNetworking/          # APIClient, HTTPTransport 프로토콜, 엔드포인트 정의
│  │  ├─ WPDomain/              # 예산 계산, isPlanDataComplete, 게스트 마이그레이션 규칙
│  │  └─ WPUtils/               # KST 날짜 유틸 (getKstToday 등), JWT 디코더
│  └─ Tests/
│     ├─ WPNetworkingTests/     # MockTransport로 응답 파싱 검증
│     ├─ WPDomainTests/
│     └─ WPUtilsTests/
├─ App/                         # SwiftUI — macOS(CI)에서만 빌드
│  ├─ Sources/
│  │  ├─ WeddingPlantApp.swift
│  │  ├─ Features/{Main,Setting,AddPlan,BudgetDetail,Chat,PlanList,Share,User}/
│  │  └─ Platform/              # URLSessionTransport, Keychain, KakaoSDK 래퍼, SSE 클라이언트
│  └─ Resources/
├─ project.yml                  # XcodeGen 설정 — Windows에서 텍스트로 편집
├─ fastlane/
│  ├─ Appfile
│  └─ Fastfile
├─ .github/workflows/ios.yml
└─ docs/
```

### 핵심 트릭 1 — 네트워킹 추상화

Windows의 `swift-corelibs-foundation`에서는 `URLSession`이 별도 모듈(`FoundationNetworking`)이고 동작이 불완전합니다. 그래서 Core에는 **전송 계층을 프로토콜로만** 두세요.

```swift
// Sources/WPNetworking/HTTPTransport.swift  — Windows에서도 컴파일됨
public struct HTTPRequest: Sendable {
    public var method: String
    public var path: String            // "/plan/schedule/list"
    public var query: [String: String]
    public var body: Data?
    public var requiresAuth: Bool
}

public struct HTTPResponse: Sendable {
    public var status: Int
    public var body: Data
}

public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest, baseURL: URL, token: String?) async throws -> HTTPResponse
}
```

- `Core`의 `APIClient`는 이 프로토콜만 사용 → Windows에서 `MockTransport`로 **전 엔드포인트 파싱 테스트 가능**.
- `URLSessionTransport`는 `App/Sources/Platform/`에 두어 macOS/iOS에서만 컴파일.

### 핵심 트릭 2 — 백엔드 응답 래퍼

백엔드는 일관되게 `{ result: boolean, data: ... }` 이므로 제네릭 하나로 처리:

```swift
public struct APIEnvelope<T: Decodable>: Decodable {
    public let result: Bool
    public let data: T?
}
```

### 핵심 트릭 3 — `.xcodeproj`를 Windows에서 관리

`.xcodeproj`는 Windows에서 만들 수 없지만, **만들 필요가 없습니다.**
`project.yml`(XcodeGen 설정, 그냥 YAML)만 Git에 커밋하고 `.xcodeproj`는 `.gitignore` 처리 → CI의 macOS 러너에서 `xcodegen generate`로 매번 생성.

```yaml
# project.yml
name: WeddingPlant
options:
  bundleIdPrefix: com.zipshowkorea
  deploymentTarget: { iOS: "17.0" }
packages:
  Core:
    path: Core
  KakaoOpenSDK:
    url: https://github.com/kakao/kakao-ios-sdk
    from: "2.22.0"
targets:
  WeddingPlant:
    type: application
    platform: iOS
    sources: [App/Sources]
    resources: [App/Resources]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.zipshowkorea.weddingplant
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
    dependencies:
      - package: Core
        product: WPModels
      - package: Core
        product: WPNetworking
      - package: Core
        product: WPDomain
      - package: Core
        product: WPUtils
      - package: KakaoOpenSDK
        product: KakaoSDKAuth
      - package: KakaoOpenSDK
        product: KakaoSDKUser
    info:
      path: App/Resources/Info.plist
      properties:
        CFBundleURLTypes:
          - CFBundleURLSchemes: ["kakao$(KAKAO_NATIVE_APP_KEY)"]
        LSApplicationQueriesSchemes: [kakaokompassauth, kakaolink]
        KAKAO_NATIVE_APP_KEY: $(KAKAO_NATIVE_APP_KEY)
        API_BASE_URL: $(API_BASE_URL)
```

환경변수(`NEXT_PUBLIC_API_BASE_URL` 대응)는 `.xcconfig` 파일 + Info.plist 주입으로 처리합니다.

---

## 3. Windows 로컬 셋업

### 3-1. Swift 툴체인 설치

사전 요구: **Visual Studio 2022 Build Tools** (C++ 워크로드 + Windows SDK). MSVC 링커가 필요하다.

```powershell
# 1) 빌드 도구 (수 GB, 설치 후 새 터미널 필요)
winget install --id Microsoft.VisualStudio.2022.BuildTools -e `
  --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

# 2) Swift 툴체인 (winget 기준 6.3.3)
winget install --id Swift.Toolchain -e

# 3) 새 PowerShell 창에서 확인
swift --version
```

또는 https://www.swift.org/install/windows/ 에서 설치 관리자(swiftly) 사용.

### 3-2. 에디터

- VS Code + 확장 `swiftlang.swift-vscode` (LSP·빌드·테스트 러너 통합)
- 또는 이 Claude Code 세션에서 그대로 편집

### 3-3. Core 패키지 빌드/테스트

**새 PowerShell 창을 열 때마다 먼저 환경 스크립트를 점(dot) 소싱해야 한다.**

```powershell
cd <저장소 폴더>
. .\scripts\swift-env.ps1     # 점 하나 + 공백 필수
cd Core
swift build
swift test
```

`swift-env.ps1` 이 없으면 실제로 이 두 가지 오류를 만난다 (둘 다 실측):

| 증상 | 원인 |
| --- | --- |
| `toolchain is invalid: could not find CLI tool 'link'` | MSVC 링커가 PATH에 없음 → `vcvars64.bat` 를 불러와야 함 |
| `unable to load standard library for target 'x86_64-unknown-windows-msvc'` | `SDKROOT` 환경변수 없음. 설치 전에 열어둔 터미널은 PATH만 갱신해도 안 되고 **환경변수 전체**를 다시 읽어야 함 |

그 외 무시해도 되는 것:

- `warning: unable to create symbolic link at ...\.build\debug (I/O error 512)`
  Windows 심볼릭 링크 권한 문제. 빌드/테스트는 정상 동작한다. 없애려면 개발자 모드를 켠다.
- PowerShell에서 `swift build 2>&1` 로 실행하면 **경고만 있어도 exit code 1** 로 보인다.
  `2>&1` 을 빼고 `$LASTEXITCODE` 로 판단할 것.

`Package.swift`에서 iOS 전용 심볼이 들어오지 않게 조건부 컴파일을 씁니다.

```swift
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
```

### 3-4. Windows에서 못 하는 것 회피

- SwiftUI 코드는 Windows에서 **문법 오류조차 못 잡습니다.** → CI 빌드가 유일한 검증.
  그래서 SwiftUI 파일은 작게, 로직은 전부 Core로 밀어넣는 게 실익이 큽니다.
- Xcode Previews 불가 → CI 시뮬레이터 스크린샷 아티팩트로 대체.

---

## 4. Mac 없이 코드 서명 인증서 만들기

Xcode 없이 openssl만으로 배포 인증서를 만들 수 있습니다.

### 4-1. 사전 준비

- **Apple Developer Program 가입 (연 $99)** — TestFlight의 전제 조건입니다.
- Bundle ID 결정: 예) `com.zipshowkorea.weddingplant`

### 4-2. CSR 생성 (Windows, Git Bash 또는 openssl 설치 후)

```bash
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr \
  -subj "/emailAddress=you@example.com/CN=Your Name/C=KR"
```

### 4-3. Apple 개발자 포털

1. Certificates, Identifiers & Profiles → **Certificates** → `+` → **Apple Distribution**
2. `ios_dist.csr` 업로드 → `distribution.cer` 다운로드
3. **Identifiers** → `+` → App IDs → Bundle ID `com.zipshowkorea.weddingplant` 등록
   (Push Notifications, Associated Domains 등 필요한 Capability 체크)
4. **Profiles** → `+` → **App Store Connect** 배포 프로파일 생성 → `WeddingPlant_AppStore.mobileprovision` 다운로드

### 4-4. .p12 변환

```bash
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey ios_dist.key -in distribution.pem \
  -out distribution.p12 -passout pass:STRONG_PASSWORD -legacy
```

`-legacy` 플래그: OpenSSL 3.x에서 macOS keychain이 읽을 수 있는 형식으로 내보내기 위함.

### 4-5. App Store Connect API 키

App Store Connect → Users and Access → **Integrations / Keys** → `+`
→ Role: App Manager → `AuthKey_XXXXXXXX.p8` 다운로드 (**재다운로드 불가, 반드시 보관**)
→ **Issuer ID**, **Key ID** 메모

### 4-6. GitHub Secrets 등록

```powershell
# base64 인코딩 (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12")) | Set-Clipboard
```

| Secret | 내용 |
| --- | --- |
| `IOS_DIST_P12_BASE64` | distribution.p12 base64 |
| `IOS_DIST_P12_PASSWORD` | p12 비밀번호 |
| `IOS_PROVISION_PROFILE_BASE64` | .mobileprovision base64 |
| `ASC_KEY_ID` | App Store Connect Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | AuthKey_XXXX.p8 **내용 전체** |
| `KAKAO_NATIVE_APP_KEY` | 카카오 네이티브 앱 키 |
| `API_BASE_URL` | 백엔드 주소 |

---

## 5. GitHub Actions → TestFlight 파이프라인

`.github/workflows/ios.yml`

```yaml
name: iOS Build & TestFlight

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      upload:
        description: "TestFlight 업로드 여부"
        type: boolean
        default: true

jobs:
  core-tests:
    runs-on: ubuntu-latest      # Core만 검증 — 빠르고 무료
    container: swift:6.0
    steps:
      - uses: actions/checkout@v4
      - run: swift test --package-path Core

  build:
    needs: core-tests
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode project
        run: xcodegen generate

      - name: Import signing assets
        env:
          P12_BASE64: ${{ secrets.IOS_DIST_P12_BASE64 }}
          P12_PASSWORD: ${{ secrets.IOS_DIST_P12_PASSWORD }}
          PROFILE_BASE64: ${{ secrets.IOS_PROVISION_PROFILE_BASE64 }}
        run: |
          echo "$P12_BASE64" | base64 --decode > /tmp/dist.p12
          echo "$PROFILE_BASE64" | base64 --decode > /tmp/profile.mobileprovision

          security create-keychain -p "" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "" build.keychain
          security set-keychain-settings -lut 3600 build.keychain
          security import /tmp/dist.p12 -k build.keychain -P "$P12_PASSWORD" \
            -T /usr/bin/codesign -T /usr/bin/security
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain

          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp /tmp/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

      - name: Archive
        env:
          API_BASE_URL: ${{ secrets.API_BASE_URL }}
          KAKAO_NATIVE_APP_KEY: ${{ secrets.KAKAO_NATIVE_APP_KEY }}
        run: |
          xcodebuild archive \
            -project WeddingPlant.xcodeproj \
            -scheme WeddingPlant \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath build/WeddingPlant.xcarchive \
            CODE_SIGN_STYLE=Manual \
            DEVELOPMENT_TEAM=YOUR_TEAM_ID \
            PROVISIONING_PROFILE_SPECIFIER="WeddingPlant AppStore" \
            CODE_SIGN_IDENTITY="Apple Distribution"

      - name: Export IPA
        run: |
          cat > /tmp/ExportOptions.plist <<'PLIST'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0"><dict>
            <key>method</key><string>app-store-connect</string>
            <key>teamID</key><string>YOUR_TEAM_ID</string>
            <key>signingStyle</key><string>manual</string>
            <key>provisioningProfiles</key><dict>
              <key>com.zipshowkorea.weddingplant</key><string>WeddingPlant AppStore</string>
            </dict>
          </dict></plist>
          PLIST

          xcodebuild -exportArchive \
            -archivePath build/WeddingPlant.xcarchive \
            -exportOptionsPlist /tmp/ExportOptions.plist \
            -exportPath build/ipa

      - name: Upload to TestFlight
        if: ${{ github.event_name == 'push' || inputs.upload }}
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8: ${{ secrets.ASC_KEY_P8 }}
        run: |
          mkdir -p ~/private_keys
          echo "$ASC_KEY_P8" > ~/private_keys/AuthKey_${ASC_KEY_ID}.p8
          xcrun altool --upload-app -f build/ipa/WeddingPlant.ipa -t ios \
            --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: ipa
          path: build/ipa/*.ipa
```

### UI 확인용 시뮬레이터 스크린샷 잡 (Windows에서 눈으로 검증하기 위한 핵심)

```yaml
  snapshots:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: brew install xcodegen && xcodegen generate
      - name: Boot simulator & run UI tests
        run: |
          xcodebuild test \
            -project WeddingPlant.xcodeproj \
            -scheme WeddingPlant \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
            -resultBundlePath build/Result.xcresult
      - name: Extract screenshots
        if: always()
        run: |
          xcrun xcresulttool export attachments \
            --path build/Result.xcresult --output-path build/screenshots || true
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: screenshots
          path: build/screenshots
```

XCUITest에서 각 화면 진입 후 `XCTAttachment(screenshot: app.screenshot())`를 `lifetime = .keepAlways`로 첨부하면, CI 아티팩트 zip을 Windows에서 받아 그대로 열어볼 수 있습니다.

---

## 6. TestFlight로 실기기 테스트

1. App Store Connect → My Apps → `+` → New App (Bundle ID 선택, SKU 지정)
2. CI가 빌드 업로드 → 10~30분 뒤 **TestFlight** 탭에 빌드 등장
3. 첫 빌드는 **수출 규정 준수(Export Compliance)** 질문에 답해야 배포됨
   → 이걸 매번 안 뜨게 하려면 Info.plist에 `ITSAppUsesNonExemptEncryption = false` 추가
4. **Internal Testing**: 팀 멤버 최대 100명, **심사 없이 즉시** 설치 가능 → 개발 중에는 이걸 사용
5. **External Testing**: 최대 10,000명, 첫 빌드는 **베타 앱 심사(보통 1일 내)** 필요
6. iPhone에 TestFlight 앱 설치 → 초대 수락 → 설치

빌드는 업로드 후 90일간 유효합니다.

---

## 7. 웹 → iOS 포팅 매핑 (이 프로젝트 기준)

### 7-1. 화면

| Next.js 라우트 | SwiftUI View | 비고 |
| --- | --- | --- |
| `/` | `OnboardingView` | Lanyard 3D는 SceneKit/RealityKit 재구현 또는 생략 |
| `/setting` | `SettingView` | 예산·이름·결혼일 |
| `/main` (96KB) | `MainView` + 하위 컴포넌트 | **반드시 쪼갤 것.** 웹의 단일 파일 패턴을 그대로 옮기면 안 됨 |
| `/calendar` | `CalendarView` | |
| `/add-plen` (78KB) | `AddPlanView` | 카카오맵 → `KakaoMapsSDK` 또는 `MapKit` |
| `/budget-detail` | `BudgetDetailView` | 차트 → Swift Charts (iOS 16+) |
| `/schedule-detail` | `ScheduleDetailView` | |
| `/plan-list` | `PlanListView` | |
| `/chat/[chatRoomId]` | `ChatView` | |
| `/share/[shareCode]` | Universal Link 핸들러 | 아래 7-5 |
| `/user` | `UserView` | |
| `BottomTabBar` | `TabView` | 홈 / 참여 플랜 / 설정 (피드는 웹과 동일하게 "준비중") |

### 7-2. 인증 — 네이티브가 오히려 더 단순해짐

웹은 서버 라우트를 경유하는 OAuth 리다이렉트 흐름이 필요했지만, 네이티브는 SDK가 직접 처리하므로
중간 단계가 통째로 사라집니다.

```
[iOS] Kakao SDK 로그인 (카카오톡 앱 or 웹뷰)
   → kakao access_token 획득
   → POST {API_BASE_URL}/plan/auth/kakao/login  { accessToken }
   → 앱 JWT 수신
   → Keychain 저장
```

- `kakao-ios-sdk` SwiftPM 추가, 카카오 개발자 콘솔에 **iOS 플랫폼 + Bundle ID** 등록 필수
- Info.plist: `CFBundleURLSchemes = kakao{NATIVE_APP_KEY}`, `LSApplicationQueriesSchemes = [kakaokompassauth, kakaolink]`
- 토큰 저장: 브라우저 스토리지 → **Keychain 하나로 통합**
- JWT payload의 `planUserId` / `sub` 디코딩 로직은 `WPUtils`에 포팅 (Windows에서 테스트 가능)

### 7-3. 게스트 모드

| 웹 (sessionStorage) | iOS |
| --- | --- |
| `weddingData` | `UserDefaults` 또는 `@AppStorage` |
| `guest_schedule_list_v1` | 파일(JSON) 또는 SwiftData |
| `plan_guest_agreement` | `UserDefaults` |
| `plan_return_path_after_login` | 인메모리 라우팅 상태 |

`KakaoLoginAlert`의 250줄짜리 effect(분기 우선순위: shareCode → returnPath → 기존 사용자 → 참여 방 → 게스트 → 신규)는
**`WPDomain`에 순수 함수 `resolvePostLoginDestination(...) -> Destination` 로 옮기세요.**
그러면 Windows에서 모든 분기를 유닛테스트로 검증할 수 있습니다. 웹에서 가장 위험했던 로직이 가장 안전해집니다.

### 7-4. 알림 — SSE는 그대로 못 씁니다 (중요)

웹은 `EventSource`로 `/plan/notification/chat/{roomId}`에 SSE 연결을 유지합니다.
iOS에서:

- **앱이 포그라운드일 때만** SSE 유지 가능. `URLSession.bytes(for:)` + `for try await line in bytes.lines`로 구현.
- **앱이 백그라운드/종료되면 SSE는 끊깁니다.** iOS는 장시간 백그라운드 네트워크를 허용하지 않음.
- 따라서 실사용 알림은 **APNs 푸시가 필수**입니다. 백엔드에 디바이스 토큰 등록 API + APNs 발송이 추가로 필요 → **백엔드 작업 항목으로 미리 잡아두세요.**

### 7-5. 딥링크 (공유 링크)

웹앱이 이미 존재하므로 Universal Links가 자연스럽게 됩니다.

1. Next 웹에 `/.well-known/apple-app-site-association` 서빙 (JSON, Content-Type: `application/json`, 리다이렉트 금지)
2. Xcode target에 Associated Domains: `applinks:your-domain.com`
3. `https://your-domain.com/share/{code}` 링크 → 앱 설치 시 앱으로, 미설치 시 웹으로

### 7-6. 날짜 처리

`lib/utils.ts`의 `getKstToday / getKstDate / getKstDateString / parseLocalDate` → `WPUtils`로 포팅.

```swift
public enum KST {
    public static let timeZone = TimeZone(identifier: "Asia/Seoul")!
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }
}
```

**Windows에서 유닛테스트 100% 가능한 영역**이므로 여기부터 시작하는 걸 권장.

### 7-7. API 엔드포인트 목록 (웹에서 추출)

```
GET/PATCH  /plan/user
GET        /plan/user/total-amount
GET        /plan/user/amount/detail
GET        /plan/user/amount/category-chart
PATCH      /plan/user/has-seen-main-guide
PATCH      /plan/user/has-seen-budget-guide
PATCH      /plan/user/has-seen-chat-guide
POST       /plan/auth/kakao/login
POST/PATCH /plan/setting
GET/POST   /plan/schedule           /plan/schedule/list
GET/PATCH/DELETE /plan/schedule/{id}
PATCH      /plan/schedule/status/{id}
GET/POST   /plan/room               /plan/room/list
GET        /plan/room/{shareCode}
POST       /plan/room/{roomId}/chat
GET        /plan/chat/name/{chatRoomId}
GET        /plan/chat/info/{chatRoomId}
GET        /plan/chat/message/count/{roomId}
GET        /plan/category/list      /plan/category/user/list
GET        /plan/category/room/{roomId}/list
SSE        /plan/notification/chat/{roomId}
```

응답은 모두 `{ result: bool, data: ... }`. 필드 오타 `onwerName`은 백엔드 계약이므로 **Swift 모델에서도 그대로 사용**(또는 `CodingKeys`로 매핑).

---

## 8. 주의: WKWebView 래핑은 리젝 위험

기존 Next 웹을 `WKWebView`로 감싸는 방식은 개발이 빠르지만
App Store Review Guideline **4.2 (Minimum Functionality)** 로 리젝될 확률이 높습니다.
하이브리드로 가더라도 푸시 알림, 카카오 네이티브 로그인, 위젯, 오프라인 캐시 등 **네이티브 고유 기능이 실질적으로 있어야** 합니다.

---

## 9. 대안: Expo(React Native) — 개발 루프만 놓고 보면 압도적

Swift를 꼭 써야 하는 게 아니라면, 지금 상황(Windows + Mac 0대 + 기존 React 코드베이스)에서는 Expo가 현실적으로 훨씬 빠릅니다.

- Windows에서 `npx expo start` → iPhone의 Expo Go 앱으로 **즉시** 실시간 확인 (Mac 불필요)
- `eas build --platform ios` → 클라우드 빌드, 서명 자동 처리
- `eas submit` → TestFlight 자동 업로드
- 기존 React 컴포넌트 로직·타입(`types/index.ts`)·API 클라이언트를 상당 부분 재사용
- 카카오 로그인·맵도 커뮤니티 네이티브 모듈 존재

단점: 네이티브 성능·최신 iOS API 접근이 Swift보다 제한적, EAS 무료 티어 빌드 큐 대기.

---

## 10. 권장 진행 순서

1. **Apple Developer Program 가입** (승인에 며칠 걸릴 수 있음 — 지금 시작)
2. Windows에 Swift 툴체인 설치 → `Core` 패키지 뼈대 생성
3. `WPModels` + `WPUtils`(KST 날짜) 포팅 → `swift test`로 Windows에서 검증
4. `WPNetworking` + `MockTransport` → 전 엔드포인트 파싱 테스트
5. `WPDomain`에 `resolvePostLoginDestination` 등 분기 로직 포팅 + 테스트
6. `project.yml` 작성 → GitHub Actions로 **빈 SwiftUI 앱 1개 빌드 성공시키기** (여기서 서명 문제를 전부 털고 감)
7. TestFlight 내부 테스트에 첫 빌드 올려서 iPhone 설치 확인
8. 그 다음부터 화면 하나씩 구현 (`/setting` → `/main` → 나머지)
9. 병행: 백엔드에 APNs 디바이스 토큰 등록 API 요청

6번을 **최대한 빨리** 뚫는 게 핵심입니다. 서명·프로비저닝이 Mac 없는 환경에서 가장 자주 막히는 지점이라, 화면을 만들기 전에 배포 파이프라인을 먼저 관통시켜야 합니다.
