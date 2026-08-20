# CLAUDE.md

이 저장소에서 작업할 때 Claude Code 가 참고할 지침.

## 무엇인가

`wedding-plant` **Next.js 웹앱의 iOS 네이티브 포팅**. Swift + SwiftUI.

### 화면은 웹과 완전히 같아야 한다

사용자의 명시적 요구다. 동작·문구·색상·글꼴에 의문이 생기면 **웹이 정답**이고, 임의로 다르게 만들지 않는다.

**기준 레퍼런스는 안드로이드 포팅이다.** 이미 웹을 1:1로 옮겨뒀고, 각 컴포넌트 주석에
대응하는 웹 Tailwind 클래스까지 적혀 있다. 새 화면을 만들 때 웹 소스를 뒤지기 전에 여기를 먼저 본다.

| 저장소 | 경로(이 사용자 머신 기준) |
| --- | --- |
| 웹 (원본) | `PERSONAL/wedding-plant` — 워크스페이스 워크트리 `apple-app` 브랜치도 동일 |
| **안드로이드 (레퍼런스)** | `PERSONAL/wedding-plant-android` |
| iOS (여기) | `PERSONAL/wedding-plant-ios` |

안드로이드에서 대응하는 파일:

| iOS | 안드로이드 |
| --- | --- |
| `App/Sources/DesignSystem/WPColor.swift` | `ui/theme/Theme.kt` (`WpColors`) |
| `App/Sources/DesignSystem/WPFont.swift` | `ui/theme/Type.kt` |
| `App/Sources/DesignSystem/Components.swift` | `ui/components/Common.kt` |
| `App/Sources/DesignSystem/Backgrounds.swift` | `ui/components/GridBackground.kt`, `Decor.kt` |
| `Features/Landing/LandingView.swift` | `ui/landing/LandingScreen.kt` |
| `Features/Main/MainView.swift` | `ui/main/MainScreen.kt` |
| `Features/Setting/SettingView.swift` | `ui/setting/SettingScreen.kt` |
| `Features/Root/BottomTabBar.swift` | `ui/nav/BottomTabBar.kt` |
| `Core/Sources/WPDomain/PlanRules.swift` | `domain/PlanRules.kt` |
| `Core/Sources/WPUtils/KST*.swift` | `core/time/Kst.kt` |

## 명령어

**Mac**

```bash
./scripts/mac-setup.sh          # Xcode 확인 → XcodeGen 설치 → Core 테스트 → .xcodeproj 생성 → Xcode 열기
swift test --package-path Core  # Core 유닛테스트
xcodegen generate               # project.yml 변경 후 .xcodeproj 재생성
```

**Windows**

```powershell
.\scripts\test.ps1              # Core 전체 테스트 (환경 준비 자동)
.\scripts\test.ps1 KstDateTests # 특정 스위트
. .\scripts\swift-env.ps1       # swift 를 직접 쓸 때. 점(.) 소싱 필수
```

Windows 에서는 `swift build 2>&1` 로 실행하면 경고만 있어도 PowerShell 이 exit 1 로 보이게 한다.
`2>&1` 을 빼고 `$LASTEXITCODE` 로 판단할 것.

## 아키텍처

### Core / App 분리는 타협이 아니라 전제다

주 개발 환경이 **Windows** 다. Windows 에서는 SwiftUI 컴파일이 불가능하므로,
**UI 가 아닌 코드는 전부 `Core/` SwiftPM 패키지에 넣는다.**

| | 위치 | Windows 빌드 |
| --- | --- | --- |
| 모델·네트워킹·도메인 로직 | `Core/` | 가능 |
| SwiftUI 화면 | `App/Sources/Features/` | 불가 |
| 플랫폼 의존 구현 | `App/Sources/Platform/` | 불가 |

새 로직을 추가할 때 **먼저 Core 에 넣을 수 있는지 검토한다.** View 안에 비즈니스 로직을 쓰면
Windows 에서 테스트가 불가능해지고, macOS 왕복 비용이 발생한다.

- `WPModels` — 백엔드 DTO, `APIEnvelope`
- `WPUtils` — `KstDate`, `JWTDecoder`
- `WPNetworking` — `HTTPTransport` 프로토콜, `APIClient`, `Endpoint` 카탈로그, `MockTransport`
- `WPDomain` — `PostLoginRouter`, `PlanCompletion`, `GuestMigration`, `BudgetSummary`

### Core 에서 금지

- `import SwiftUI` / `UIKit` / `Security` — Windows 빌드가 깨진다
- `import Foundation` 의 `URLSession` — Windows 의 swift-corelibs-foundation 에서는 별도 모듈이고 동작이 불완전하다.
  전송 계층은 `HTTPTransport` 프로토콜로 추상화하고, 구현은 `App/Sources/Platform/URLSessionTransport.swift` 에 둔다.
- 함수 안에서 `Date()` 직접 호출 — 자정 경계 테스트가 불가능해진다.
  `KstDate.today(now:)` 처럼 **`now:` 파라미터로 주입**받게 만든다.

### .xcodeproj 는 커밋하지 않는다

Windows 에서 생성할 수 없으므로 `project.yml`(XcodeGen) 만 커밋하고 `.xcodeproj` 는 매번 생성한다.

**타깃·빌드 설정·의존성 변경은 반드시 `project.yml` 에서 한다.** Xcode UI 에서 바꾼 설정은
다음 `xcodegen generate` 때 사라진다. (소스 파일 추가는 폴더 기준이라 그냥 된다)

예외: Xcode 에서 실기기 실행 시 고르는 **Team** 은 생성된 `.xcodeproj` 에만 남는다.
매번 고르기 싫으면 `project.yml` 의 `DEVELOPMENT_TEAM` 에 팀 ID 를 박는다.

## 환경 설정

`.env` 를 쓰지 않는다. **xcconfig → Info.plist → `Bundle.main`** 경로로 주입한다.

- `Config/Base.xcconfig` — 커밋됨. 기본값과 `#include? "Local.xcconfig"`
- `Config/Local.xcconfig` — **gitignore.** 각자의 백엔드 주소·팀 ID. `Local.example.xcconfig` 를 복사해 만든다
- `project.yml` 의 `info.properties` 에 `API_BASE_URL: $(API_BASE_URL)` 로 연결되어 있다
- 읽는 곳은 `AppEnvironment.baseURL()`

xcconfig 에서 `//` 는 주석이다. URL 은 `http:/$()/example.com` 처럼 `$()` 로 끊어 써야 한다.

**서버 전용 비밀값(카카오 REST API 키, client secret 등)을 앱에 넣지 않는다.**
번들에 들어간 값은 `.ipa` 를 풀면 추출된다. 그런 값은 백엔드에만 둔다.

## 백엔드 계약

> **먼저 읽을 것: `wedding-plant-android/docs/IOS_PORTING_NOTES.md`**
> 안드로이드 팀이 iOS 를 위해 남긴 문서다. 코드만 봐서는 모르는 백엔드 함정과
> 실제로 겪은 버그가 정리돼 있다. 아래는 그중 이 저장소에 이미 반영한 것들이다.

### 절대 틀리면 안 되는 것

| 항목 | 규칙 |
| --- | --- |
| 카카오 로그인 본문 키 | **`kakaoToken`**. `accessToken` 으로 보내면 400 |
| `POST /plan/schedule` | **`roomId` 필수.** 빼면 200 인데 목록에 영영 안 나옴 |
| `PATCH /plan/schedule/{id}` | 날짜를 미정으로 되돌리려면 **명시적 `null`**. 키를 빼면 "변경 없음" |
| 프로필 수정 | `PATCH /plan/user` 는 **항상 400**. `POST /plan/setting` 을 쓴다 |
| `DELETE /plan/schedule/{id}` | 200 + **빈 본문**. 성공인데 파싱 실패로 뒤집지 말 것 |
| 채팅 메시지 `id` | **숫자**. String 으로 디코딩하면 방 전체가 빈 화면 |
| `createDate` | **UTC**. 앞 10글자를 자르면 9시간 어긋난다 → `KstInstant` |
| 게스트 카테고리 | `/plan/category/list` 를 **인증 없이**. 안 그러면 게스트가 플랜을 못 만듦 |
| 멤버 목록 래퍼 | `list` 또는 `members` — **둘 다 방어** |
| 푸시 페이로드 | 값이 전부 **문자열**. `chatRoomId` 도 `"1"` |
| 세션 정리 | **401/403 에서만.** 5xx·네트워크 오류로 지우면 강제 로그아웃 |



- 모든 API 는 `${API_BASE_URL}/plan/...`, 응답은 일관되게 `{ result: Bool, data: ... }` → `APIEnvelope<T>`
- 엔드포인트는 전부 `Core/Sources/WPNetworking/Endpoint.swift` 에 모은다. 화면에서 경로 문자열을 직접 만들지 않는다.
- **금액 단위는 만원.**
- `Plan.onwerName` 은 백엔드 응답의 오타를 그대로 유지한 필드다. 이름을 고치지 말 것 (읽기용 `ownerName` 별칭 제공).
- 알 수 없는 enum 값이 와도 디코딩이 깨지지 않도록 권한·상태는 `RawRepresentable` 구조체로 둔다.
  합성 Codable 은 `{"rawValue":"X"}` 로 인코딩하므로 `init(from:)`/`encode(to:)` 를 직접 쓴다.
- 숫자가 문자열로 오는 경우가 있어 `@LooseInt` 래퍼로 방어한다.

## 시간 처리

한국 사용자 대상이므로 **KST 기준으로 통일**한다. `Core/Sources/WPUtils/KST.swift` 의 `KstDate` 를 쓴다.
`KST.secondsFromGMT` 는 고정 +9 오프셋이다 (tz 데이터베이스 의존을 피하고 웹 구현과 결과를 일치시키기 위함).

## 데모 모드

실행 인자 `-WPDemoMode` 를 주면 `DemoTransport` 가 주입되어 **백엔드 없이** 채워진 화면이 뜬다.
CI 스크린샷 촬영과 시뮬레이터 확인에 쓴다.

스킴이 두 개다(`project.yml` 에 정의 — `xcodegen generate` 해도 유지된다).

| 스킴 | 동작 |
| --- | --- |
| `WeddingPlant` | 실제 백엔드 (`Config/Local.xcconfig` 의 `API_BASE_URL`) |
| `WeddingPlant (Demo)` | 데모 데이터 |

`-WPForceOnboarding` 을 켜면 **비로그인 + 빈 사용자**로 시작해 랜딩·설정 6단계를 처음부터 볼 수 있다.
끄면 플랜이 완성된 사용자라 `SettingViewModel.prefill` 이 곧바로 메인으로 보낸다(웹 명세대로).

데모 데이터는 `App/Sources/Platform/DemoTransport.swift` 의 `DemoData` 에서 고친다.
결혼일은 항상 "오늘 + 92일" 이라 언제 캡처해도 D-92 로 보인다.
일정은 지남/D-day/임박/예정 상태가 한 번씩 나오도록 날짜를 배치해뒀다.

## 디자인

**UI 작업 시 `impeccable` 스킬을 항상 적용한다.** SwiftUI 라면 그 스킬의 `reference/ios.md` 를 먼저 읽는다.

스킬은 라이선스가 우리 것이 아니라 저장소에 포함하지 않았다(이 저장소는 공개).
각자 머신의 `.claude/skills/` 에 복사해야 한다. 원본: `PERSONAL/wedding-plant/.claude/skills/`
(`hallmark`, `impeccable` 두 개가 여기에만 있다)

### HIG 기본값보다 웹 일치가 우선이다

`impeccable/reference/ios.md` 는 시맨틱 시스템 컬러·Dynamic Type·다크모드·large title 을 요구하지만,
이 프로젝트는 **의도적으로 따르지 않는다.** 그렇게 하면 웹에서 멀어지기 때문이다.
impeccable 자체가 *"The brief wins. Redirecting a clear brief toward your taste is failure."* 라고
명시하고 있고, 여기서 브리프는 "웹과 똑같이" 다.

구체적으로:

- **색**: `WPColor` 만 쓴다. 브랜드 핑크 `#EE2B8C`, 배경 `#FCFBFC`. 화면 코드에 hex 직접 금지.
- **글꼴**: 웹과 같은 TTF. `WPFont.hak(_:_:)` = 덩근미소(기본), `WPFont.tmoney(_:_:)` = 사용자 입력값(이름·플랜 제목).
  크기는 `fixedSize` 로 고정한다 — Dynamic Type 을 쓰면 웹과 레이아웃이 어긋난다.
- **다크모드는 만들지 않는다.** 웹에 없다. `UIUserInterfaceStyle: Light` 로 고정돼 있다.
- **하단 탭은 4개** — 홈 / 피드 / 참여 플랜 / Settings. `Settings` 가 영문인 것도 웹 그대로다.
  피드는 라우팅 없이 "준비중" 알림만 띄운다. iOS `TabView` 대신 커스텀 바를 쓴다(웹과 모양이 달라서).
- 배경에는 항상 `WPScreenBackground` — 배경색 + 점 그리드. 랜딩·설정만 `showsDecor: true`.

### 검증

프론트엔드 변경은 **실제로 화면을 캡처해 눈으로 확인하기 전까지 완료로 보고하지 않는다.**
Mac 이면 시뮬레이터, Windows 면 CI 아티팩트(`docs/VIEW_THE_APP.md`)를 쓴다.

## CI

- `.github/workflows/ios.yml` — Linux 에서 Core 테스트 + macOS 시뮬레이터 스크린샷·동영상.
  **시뮬레이터 빌드는 코드 서명이 필요 없다.** Apple 개발자 계정 없이 동작한다.
- `.github/workflows/device.yml` — 수동 실행. 무서명 `.ipa` 또는 TestFlight 업로드.

서명 자산(`signing/`, `*.p12`, `*.p8`, `*.mobileprovision`)은 절대 커밋하지 않는다.
**이 저장소는 공개다.** 커밋 전에 개인정보·자격증명이 섞이지 않았는지 확인할 것.

## 컨벤션

- **숫자를 그대로 보여줄 때는 `Text(verbatim:)` 을 쓴다.**
  `Text("\(someInt)")` 는 `LocalizedStringKey` 로 해석되어 로케일 숫자 포맷이 붙는다.
  연도가 `2,026` 으로 나오는 식이다. 금액처럼 **의도적으로** 천 단위를 넣을 때만
  `wpThousands(_:)` 로 문자열을 먼저 만들고 넣는다.
- 주석과 UI 문구는 한글이 기본
- 주석은 "무엇을"이 아니라 **"왜"** 를 적는다. 특히 웹과 다르게 구현한 지점은 이유를 남긴다
- 코드·문자열에 이모지를 **새로 추가하지** 않는다.
  단, **웹 원문에 있는 이모지는 그대로 옮긴다** (예: 설정 축하 문구, "모든 플랜을 완료했어요! 🎉").
  빼면 문구가 웹과 달라진다.
- 사용자 응답은 한글로 한다 (코드·명령어·기술 용어는 영어 유지)

## 하드 트랩 (실제로 당한 것들)

| 증상 | 원인 / 대응 |
| --- | --- |
| 글꼴이 시스템 폰트로 나옴 | `Font.custom` 은 **PostScript 이름**을 요구한다. 파일명이 아니다. 틀려도 크래시 없이 조용히 대체된다. 값은 `WPFont.swift` 참고 — TTF 의 name 테이블(nameID 6)에서 직접 뽑은 것이니 추측으로 고치지 말 것 |
| 연도가 `2,026` 으로 나옴 | `Text("\(Int)")` 는 `LocalizedStringKey` → 로케일 숫자 포맷. `Text(verbatim:)` 을 쓴다 |
| 달력이 영어로 나옴 | `CFBundleDevelopmentRegion: ko` + `CFBundleLocalizations: [ko]` 가 `project.yml` 에 있어야 한다 |
| 리스트가 비어 나옴 | `roomId` 가 있으면 경로가 `/plan/schedule/room/{id}/list` 로 바뀐다. 금액도 `/plan/room/total-amount/{id}` 다 |
| 설정 화면이 곧바로 메인으로 넘어감 | 정상 동작이다. 플랜이 완성된 사용자면 `prefill` 이 스킵한다. 플로우를 보려면 `-WPForceOnboarding` |
| UI 테스트가 버튼을 못 찾음 | `.accessibilityIdentifier` 를 감싼 뷰에 걸면 `app.buttons[...]` 로 안 잡힌다. `Button` 자체에 붙인다 (`WPNextButton(identifier:)` 처럼) |
| 카테고리 색이 웹과 다름 | `PlanRules.categoryColorHex` 는 JS 의 **Int32 오버플로 해시**를 재현해야 한다. `&<<` `&-` `&+` 와 `Int64` abs 를 쓴다 |
| `'Category' is ambiguous for type lookup` | Objective-C 런타임에 `typedef struct objc_category *Category` 가 있다. 모델 이름을 `PlanCategory` 로 쓴다 (안드로이드의 `Category` 를 그대로 옮기면 안 된다) |
| pull 후 폰트·스킴이 안 보임 | `project.yml` 이 바뀌었으면 `xcodegen generate` 를 다시 돌려야 한다 (`./scripts/mac-setup.sh`) |

## 문서

| 문서 | 내용 |
| --- | --- |
| **`docs/STATUS.md`** | **현재 상태·다음 할 일. 작업 시작 전에 먼저 읽을 것** |
| `docs/RUN_ON_MAC.md` | Mac 에서 구동·실기기 설치 |
| `docs/INSTALL_ON_IPHONE.md` | Mac 없이 아이폰 설치 (TestFlight / Sideloadly) |
| `docs/TESTING.md` | 테스트 실행·작성 |
| `docs/VIEW_THE_APP.md` | CI 스크린샷·동영상으로 화면 확인 |
| `docs/IOS_DEV_ON_WINDOWS.md` | 전체 전략, 인증서 발급, 웹→iOS 포팅 매핑 |
| `Core/README.md` | Core 설계 규칙 |
