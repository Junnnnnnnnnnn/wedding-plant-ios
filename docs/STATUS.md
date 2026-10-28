# 현재 상태 / 인수인계

## 2026-10-28 — Android v42 · v43 청첩장 이식

- Android `main` `2c2fb4c` 까지 받았다(4커밋, 청첩장만). 청첩장 사진 JPEG 85 → **WebP 80**(c857963 · 웹 e227871), 기존 청첩장
  `고치기`는 **미리보기부터**(2c2fb4c), 20장 표지 교체 · 편집 잠금(1e62d83), 홈 `새 축하 N` 읽음 기준을 청첩장별로(1e62d83).
- iOS 는 홈의 `새 축하 N` 이 늘 0 이던 것(읽음 기준이 없었음)도 이번에 함께 채웠다.
- Android 의 `preparingCover` · `refreshing` 잠금은 iOS 구조(고른 순간 올리고, 충돌은 저장 안에서 최신 판을 받음)에서는 같은 틈이
  생기지 않아 옮기지 않았다. 20장 표지 교체에서 iOS 는 원래 `prefix(0)` 로 **아무 일도 안 하던** 버그가 있었고 고쳤다.
- 검증: Core 425개, 앱 단위 테스트 59개(새 `InvitationPhotoPrepTests` — EXIF 회전 · HEIC · 투명 PNG 흰 바탕 · 거절 문구),
  새 `InvitationEditorEntryUITests`(새 청첩장은 구성부터 · 기존은 미리보기부터 · `구성` 단추), 기존 청첩장 UI 테스트
  (키보드 · 카카오맵 · 광고 · 저장→공개 · 패스 권한) 통과. 운영 서버에는 요청하지 않았다.
- Android 에뮬레이터와 iOS 시뮬레이터 1:1: [6쌍](test-reports/2026-10-28-invitation-parity/README.md). 시뮬레이터에서 사진 앱으로
  실제로 고른 사진이 WebP(800×1600, 세로)로 올라가는 것을 확인했고, 그 과정에서 **저장하면 새 표지가 빈 정원으로 바뀌는** iOS 버그를
  찾아 `InvitationRules.mergePhotos`(Android 와 같음)로 고쳤다. 새 `InvitationPhotoAndWishesUITests`(사진 고르기 → 업로드 → 저장,
  홈 `새 축하 N` 두 번 실행).
- 미검증: 실제 R2 업로드(운영 청첩장을 건드리지 않음).

## 2026-10-23 — Android v40 · v41 피드 이식 (1.0.1)

- Android `main` `55d40d0` 까지 받아 비교했다. 바뀐 것은 피드(견적 후기)뿐이다: 공유하기(b64cfe7), 내 후기 수정하기 ·
  고치기 · 내리기, 후기 사진 보기(썸네일 · 격자 · 크게 보기) · 올리기(3장 · WebP), 업체 고르기, 올라온 후기에 있는
  카테고리만 칩(4a785da · 55d40d0). 알림 권한 lint 수정(4b70d9f · 76c8ab2)은 Android 전용이라 옮길 것이 없다.
- Android 에뮬레이터(API 35, 411dp)에서 `FeedParityTest` · `FeedCategoriesTest` 11개와 비교용 임시 캡처 3개를 돌리고, iOS 는
  데모 데이터(`-WPFeedParity`)로 같은 장면을 찍었다. 16쌍: [compare](test-reports/2026-10-23-feed-parity/compare/).
- 검증: Core 422개, 앱 단위 테스트(새 `FeedEditorTests` 9개 — 409 재정렬 · 사진 키 재시도 · 404 내리기 · WebP 방향/크기 · HEIC),
  `FeedParityUITests` 6개. 운영 서버에는 요청하지 않았다(데모 · 가짜 전송 계층).
- 미검증: 실제 R2 업로드(운영 계정으로 후기를 올리면 공개 피드에 보이므로 하지 않았다), 실기기 사진 앨범의 HEIC 원본.

## 2026-10-14 — 전체 화면·동작 비교 HTML

- [전체 화면 비교](all-screen-comparison-20261014/index.html): 172개 항목. Android 왼쪽 / iOS 오른쪽, 양쪽 캡처 106개·한쪽 캡처 57개·미캡처 9개. 등록·수정·삭제, 기능·상태 필터, 확대, 검수 메모와 CSV, 정원 연속 프레임을 제공한다. **172개 모두의 일치·기능 완료를 뜻하지 않는다.**
- 확인된 차이는 로그인 배치·버튼, 서류 보관함 구조, iOS 구매 미연결 등이며 별도로 표시했다. iOS 비밀번호 재설정 테스트는 자동 강력한 암호 덮개가 나타난 상태에서 두 번 실패해 미해결로 남겼다.
- Android 기존 102개 중 101개 통과, 가로 정원 1개는 동일 테스트 재실행 통과. iOS UI 27개 중 23개 통과, 실패 4개 중 PDF 진입·피드 가져오기·혼자 쓰는 채팅 3개는 재실행 통과. 초기 실패 기록을 지우지 않았다. iOS 네이티브/모션 9개와 Core 모션 2개 통과.
- 추가 캡처 검증: iOS 실제 뷰 35개를 독립 렌더링하고 상·중·하단/빈 목록/오류를 기록했다. 달력 날짜별 추가, 프로필 저장·탈퇴 확인·로그아웃, 후기 일정 선택·입력 화면도 검증했다. Android 기본 화면/온보딩 캡처 테스트는 `scripts/comparison/android/AllScreenReviewShotTest.kt`에 보관한다.
- 운영 데이터 변경 없이 테스트 전송 계층을 사용했다. 앱 코드는 이번 작업에서 바꾸지 않았으며, 시뮬레이터는 작업 뒤 운영 API로 정상 실행했다. 실결제·실계정 Google 인증·실기기 푸시·하객 CRUD 등은 미검증으로 명시했다.
- 재생성: `scripts/comparison/catalog.py`, `build.py`, `template.html`. 캡처 원본/xcresult/실행 로그는 `/tmp/wp-all-screens-20261014/`; 배포 가능한 오프라인 HTML·이미지·해시·검증 결과는 `docs/all-screen-comparison-20261014/`에 있다.

## 2026-10-14 — 청첩장 Android 대조 수정

- 비교 기준: Android `main`의 `9a6e1c2`, 390×844 논리 크기, 동일한 예시 이름·사진·날짜. [17개 항목 비교 갤러리](invitation-comparison-20261014/index.html)는 Android 왼쪽/iOS 오른쪽이며 수정 전 iOS도 전환할 수 있다.
- 구성 카드·표시 스위치·순서 변경, 표지·날짜·사진첩·계좌의 하단 편집 패널, 저장 후 공개 이동, 공개 상태/QR/11개 항목 그리드를 Android 구조로 맞췄다. 장소 검색은 기존 `/plan/place/search` 프록시에 연결했다.
- 제목 정렬, 사진 영역, 본문 행간, 달력 연도, 꽃 장식, 방명록 예시 하객을 수정했다. Android의 Noto Serif 파일을 라이선스와 함께 포함했고, 문 이미지의 SwiftUI asset-catalog 조회를 UIKit 번들 로딩으로 바꿨다.
- 운영 API 설정을 유지한다. 비교/공개 테스트는 격리된 응답과 데모 계정을 사용하며 운영 청첩장을 쓰지 않는다. 임시 편집본 키는 API 환경·방·계정으로 분리하고 데모 테스트에서는 저장하지 않는다.
- 검증: Core XCTest 394개 + Swift Testing 5개, Android 기존 청첩장 테스트 16개 및 본문/추가 패널 캡처 3개. iOS 저장→공개, 무료/유료 노출, Google 테스트 광고 실제 로딩, 예시 진입, 정원 낙하 회귀 검증. QR은 이미지에서 URL을 다시 디코딩해 검증한다.
- 비교의 한계: 일부 기본 아이콘·날짜 선택기는 OS별 구현이며 픽셀 전체 일치를 주장하지 않는다. 본문 정원은 위치 비교를 위해 모션을 정지했다. 문 열림의 모든 시간 프레임, 실제 사용자 사진 업로드, 운영 장소 검색 결과 선택은 이번 캡처 테스트에서 끝까지 수행하지 않았다. QR 저장은 iOS 파일 내보내기다.
- 전체 원본/로그/xcresult: `/tmp/wp-invitation-compare-20261014/`. 갤러리 PNG는 원본 네이티브 캡처를 390px로 축소·병치했다. iOS Display P3를 sRGB로 변환했으며 색상이나 UI 내용을 임의로 보정하지 않았다. 본문은 공통 상단 104pt, 시스템 하단 24pt를 제외했다.


마지막 갱신: 2026-10-14

iOS 기본 API를 Android와 같은 `https://api.weddingplant.app`으로 전환했다.
Keychain 세션은 API 주소별로 분리하며, 이전 공용 토큰은 이관하지 않으므로 전환 후 재로그인해야 한다.
시뮬레이터도 Keychain 저장을 위해 ad-hoc 서명(`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`)으로 빌드한다.
서버별 세션 분리·저장소 재생성 후 유지 테스트가 통과했다.

Android v35 이식의 최신 구현·검증·미완료 항목은 [ANDROID_PARITY_20261013.md](ANDROID_PARITY_20261013.md)를 기준으로 본다.
이메일 인증, 준비 패스 화면·서류·내보내기, 청첩장·정원 모션, 채팅·권한 등을 추가했고 Core 389개가 통과했다. 실제 Android/iOS 화면 14쌍과 낙하 133프레임을 대조한 기록도 추가했다.
실서비스 인증·두 계정 연동·푸시, Apple 구매 검증 및 시각 대조에서 확인한 UI·모션 차이가 남아 있어 출시 완료 상태는 아니다.

아래는 **2026-09-18 인수인계 기록**이며 당시 테스트 수·미구현 목록을 현재 상태로 해석하지 않는다.

배경은 `CLAUDE.md` 를 먼저 읽을 것. 이 문서는 **지금 어디까지 됐고 다음에 뭘 할지**만 다룬다.

> **작업 전에 반드시 읽을 것: `wedding-plant-android/docs/IOS_PORTING_NOTES.md`**
> 안드로이드 팀이 iOS 를 위해 남긴 문서. 코드만 봐서는 모르는 백엔드 함정이 정리돼 있다.

---

## 한 줄 요약

**웹·Android·iOS 를 같은 화면으로 맞추는 작업이 진행 중이다.** 안드로이드는
웹과 사실상 일치하고, iOS 가 한 달 뒤처져 있던 것을 따라잡는 중이다.

- 저장소: <https://github.com/Junnnnnnnnnnn/wedding-plant-ios> (**공개**)
- Core 테스트: **303개 통과** (Windows/Linux)
- CI 시뮬레이터 빌드 + 스크린샷 통과

### 맞춘 화면 (CI 캡처로 눈으로 확인함)

| 화면 | 상태 |
| --- | --- |
| 가이드 오버레이 | 머리 면의 `?` — 앵커 다섯은 웹과 같은 이름 |
| 후기 쓰기 | 완료한 일정에 별점 + 한 줄 (모달) |
| 로그인 문 | 웹 `LoginView.tsx` 폰 레이아웃 — 분홍 전체 면 + 왼쪽 정렬 |
| 홈 `/main` | **C안** — 분홍 머리 면 → 이번 달에 할 일 → 그 다음 |
| 예산 상세 | **도넛** + 카테고리 3열 표(예산·사용·남음) |
| 등록 `/add-plen` | **시트 한 장** — 제목이 머리 면 안, 결제 체크·시각 줄 |
| 온보딩 `/setting` | 5단계 — 마지막 `함께할 사람` 추가 |
| **피드** | 견적 후기 목록 + 상세(시세 자) — 탭이 "준비중" 이던 자리 |
| **자랑하기** | 목록 + 상세 모달 + 홈 토글 |
| 프로필 `/user` | 라벨을 상자 밖 위로, 저장 버튼 `저장` |
| 참여 플랜 | 이름·D-day → 남은 예산 → 대화 순서, 홈과 같은 막대 |
| **문의하기** | 프로필 맨 아래 메뉴 줄(시안 B안) — 밑줄 두 개에서 옮겨 왔다 |

### 곁들여 붙은 것

- **배우자 귀속** — 수락하면 그 방이 내 플랜. `AppEnvironment` 한 곳에 두고
  화면들이 읽는다. 수락 전 경고, `?as=spouse` 역할, 불투명 가림막 포함.
- **초대 띠** — 온보딩에서 초대를 건너뛴 사람의 유일한 재진입점.
- **가이드 오버레이** — 머리 면의 `?`. 앵커 다섯은 웹과 같은 이름이다.

### 아직 안 맞춘 것

| 항목 | 웹·Android | iOS |
| --- | --- | --- |
| 인앱 알림(SSE) | 있음 | 없음 |
| 카카오 로그인 | 됨 | 코드·키 준비됨. **콘솔에 iOS 플랫폼 등록만 남음** |
| Sign in with Apple | 웹·Android 에 없음 | **iOS 에만 있다**(심사 지침 4.8) |
| 캘린더 보드(월별 컬럼) | 넓은 화면 전용 | 해당 없음(폰 전용 앱) |
| 지도(카카오 SDK) | 있음 | 카카오맵 링크로 대체 |

---

## 파리티 작업에서 찾은 실제 버그

코드를 나란히 놓고 보지 않으면 안 보이던 것들이다.

1. **`PlanPermission` 에 `SPOUSE` 가 없어 배우자가 자기 플랜을 못 고쳤다.**
   `canEdit` 이 `owner || write` 로 긍정 열거라 권한이 늘었을 때 빠졌다.
   정책은 **"`READ` 면 거절"** 이다 — 새 게이트도 같은 형태로 쓸 것.
2. **사용률이 웹과 1% 달랐다.** 웹은 `Math.round`, iOS 는 내림이라 `2/3` 이
   67% vs 66% 였다.
3. **홈 정렬 기본값이 최신순이라 지난 일정이 목록 맨 아래에 묻혔다.**
4. **홈 목록이 데이터를 받고도 앞 두 장이 뼈대로 남았다.** `LazyVStack` 이
   이미 그린 행을 위치로 재사용했다 — **화면을 봐야만 보이는 종류다.**
5. **피드의 `내 플랜에 담기` 가 `roomId` 없이 열렸다.** 귀속된 배우자가
   거기서 담으면 새 일정이 **화면에 보이지도 않는 개인 플랜에** 저장된다.
   `AddPlanViewModel` 이 저장 시점에 스스로 메우도록 한 곳에서 막았다.
6. **뼈대 시머의 `repeatForever` 가 UI 테스트를 영원히 기다리게 했다.**
   관계없는 채팅 테스트가 353초 만에 죽었다.

**안드로이드에서도 둘 고쳤다** — 로그인 문구(웹이 뒤늦게 같은 방향으로 고쳐
갈라져 있을 이유가 없어졌다), 피드 카테고리 칩(받은 후기에서 뽑아 쓰다가
스크롤할 때마다 칩이 늘어 누르려던 칩이 밀렸다).

---

## 문의 주소는 세 곳이 같아야 한다

`support@weddingplant.app` — 웹 `lib/legal.ts` 의 `LEGAL_INFO.contactEmail`,
안드로이드 `AppConfig.supportEmail`, iOS `AppConfig.supportEmail`.
**갈라지면 한쪽으로 온 문의를 아무도 안 본다** (iOS 만 개인 지메일이었다).
메일 제목 `[웨딩 플랜트] 문의` 도 셋이 같다 — 받는 쪽 메일함 규칙으로 거르는
값이라 다르면 한쪽이 규칙에 안 걸린다.

App Store Connect 의 **지원 URL**(지침 1.5)과 지원 연락처에도 같은 값을 넣는다.
주소 자체는 Cloudflare Email Routing 이 개인 메일함으로 전달한다.

## 검사 도구

- **`swiftc -frontend -parse <파일>`** — 구문만 본다. Windows 에서 App 타깃은
  SwiftUI 가 없어 타입체크가 안 된다.
  **교차 파일 문제(이름 충돌·import 누락)는 여기서 안 잡힌다** — 실제로 둘 다
  CI 에서 처음 알았다.
- **`.\scripts	est.ps1`** — Core 테스트. 규칙은 되도록 Core 에 두고 여기서 고정한다.
- **CI → `.\scripts\preview.ps1`** — 시뮬레이터 빌드 + 화면 캡처. **화면은 이걸로만
  볼 수 있다.** 레이아웃 문제는 타입체크로 안 잡힌다.

`concurrency: cancel-in-progress` 라 **CI 가 도는 중에 또 밀면 이전 실행이 취소**된다.
결과를 볼 거면 끝난 뒤에 밀 것.

### 푸시 전에 돌리는 감사 둘 — `python scripts/audit.py`

교차 파일 문제는 파일 단위 구문 검사로 안 잡혀 **CI 왕복을 두 번 썼다.**
그 뒤로는 푸시 전에 이 둘을 돌린다.

1. **private/internal 이름 충돌** — 파일 private 선언도 모듈 범위에서 재선언으로
   잡힌다. `SectionHeader`(UserView) 와 `ActivityShareSheet`(SettingView) 가 그랬다.
2. **모듈 심볼 사용처 ↔ import 대조** — `BrandSheet` 의 `WPUtils`,
   `FeedDetailView` 의 `WPNetworking`, `AppEnvironment` 의 `WPUtils` 가 그랬다.
   **심볼 목록을 손으로 적지 않는다** — 빠뜨리면 감사가 통과해도 CI 가 깨진다
   (`JWTDecoder` 로 겪었다). `Core/Sources/<모듈>` 의 `public` 선언에서 뽑는다.

**거짓 경고를 남기지 말 것.** 최상위 선언만, 주석은 빼고 센다 — 안 그러면
중첩된 `Tab` 두 개와 주석 속 `GuestMigration` 이 잡히고, 그런 게 쌓이면 아무도
감사를 안 본다. `WPFont` 는 Core 가 아니라 `DesignSystem` 에 있다.
일부러 깨뜨려 둘 다 잡히는 것을 확인했다.

### UI 테스트가 멈추는 함정

**끝나지 않는 애니메이션을 두지 말 것.** XCUITest 는 앱이 idle 이 될 때까지
기다린다. 뼈대 시머는 데모 모드에서 정지한다(`SkeletonBox.animated`).

---

## 다음에 할 일 (우선순위)

### 1. 카카오 콘솔에 iOS 플랫폼 등록 — **지금 막혀 있는 것**

코드는 다 붙었고 CI 빌드도 통과했다. 남은 것은 **콘솔 등록 하나**다.

- <https://developers.kakao.com> → 웨딩플랜 앱 → **앱 설정 > 플랫폼 > iOS 등록**
- 번들 ID: `app.weddingplant` (안드로이드 패키지명과 같다)
- **iOS 는 키 해시가 필요 없다** — 번들 ID 하나면 된다

**키는 이미 있다.** 안드로이드와 같은 앱이라 네이티브 앱 키가 같고,
`wedding-plant-android/local.properties` 의 값을 `Config/Local.xcconfig` 에 옮겨 뒀다
(gitignore 됨). 실기기용 빌드를 CI 로 받으려면 저장소 시크릿도 필요하다:

```powershell
gh secret set KAKAO_NATIVE_APP_KEY --body "<네이티브 앱 키>"
```

**등록만으로는 안 되고 플랫폼을 따로 받는다** — 안드로이드가 되는 것과 무관하다.
등록되지 않은 번들 ID 로 로그인하면 카카오가 거절한다.

#### 확인된 것 (2026-09-18)

- **운영 백엔드의 카카오 로그인은 살아 있다.** `POST /plan/auth/kakao/login` 에
  가짜 토큰을 넣으니 `kapi.kakao.com` 까지 갔다가 401 이 돌아왔다 — 경로 전체가
  뚫려 있다는 뜻이다.
- **서버에는 카카오 키가 필요 없다.** 백엔드는 사용자 access_token 만 들고 카카오에
  물어본다. 운영 `web.env` 의 카카오 키가 비어 있는 것은 **웹 OAuth 용**이라
  앱 로그인과 무관하다.
- `Config/Local.xcconfig` 의 `API_BASE_URL` 은 안드로이드와 같은
  `https://api.weddingplant.app` 을 본다.

#### 키 없이 배포되는 것을 빌드가 막는다

게스트 모드가 없어 **키가 비면 아무도 앱에 못 들어온다** — 화면 구경도 못 하고,
설치한 사람은 앱이 고장 난 줄 안다. 그래서 `project.yml` 의
`카카오 앱 키 확인 (Release)` 이 Release 빌드를 실패시킨다.
Debug 는 막지 않는다(CI 는 데모 모드, 실기기는 `개발용 토큰으로 로그인`).

#### 실제로 로그인을 눌러 보려면

**윈도우에서는 빌드할 수 없다.** 화면은 CI 캡처로 보지만 로그인은 대화형이라
CI 로 확인할 수 없다. 길은 둘이다.

1. `아이폰 설치용 빌드` 워크플로 → `unsigned-ipa` → Sideloadly 로 아이폰에 설치
   (`docs/INSTALL_ON_IPHONE.md`). 무료 Apple ID 로 된다.
2. 맥에서 `xcodegen generate` 후 Xcode 실행 (`docs/RUN_ON_MAC.md`).

### 2. Apple Developer Program 가입 후 엔타이틀먼트 켜기

`App/Resources/WeddingPlant.entitlements` 에 `applesignin` 과 `aps-environment`
가 들어 있다. **유료 계정이 있어야 서명된다** — 기본은 꺼 두어 무료 계정
실기기 설치와 CI 시뮬레이터 빌드가 그대로 돈다.

켜는 법: `Config/Local.xcconfig` 에
`WP_ENTITLEMENTS = App/Resources/WeddingPlant.entitlements`

### 3. 백엔드 `APPLE_BUNDLE_IDS` 설정 + 배포

Apple 로그인은 백엔드에 커밋만 되어 있고 **밀지 않았다**(푸시가 곧 배포다).
운영에 올릴 때 환경변수 `APPLE_BUNDLE_IDS=app.weddingplant` 를
함께 넣어야 한다 — **비어 있으면 애플 로그인이 막힌다**(`aud` 를 검사할 수
없는 상태로 열어 두지 않는다).

`plan_user` 에 `appleId`·`appleEmail` 컬럼이 늘어난다(`synchronize: true`).

### 4. App Store Connect 메타데이터

- **지원 URL**(지침 1.5) — 앱 안의 문의하기와 별개로 **이게 필수 항목**이다.
- 개인정보처리방침 URL — `https://weddingplant.app/privacy`
- 앱 개인정보 보호 설문(수집 항목 신고)
- 스크린샷 6.9인치(1320x2868) 필수

### 5. 인앱 알림(SSE)

읽기 타임아웃을 끄면 안 된다 — 서버가 조용히 끊었을 때 영원히 기다려,
앱은 멀쩡한데 알림만 안 오는 상태가 된다. keep-alive(30초)의 3배를 둘 것.

### 6. 공유 링크를 Universal Link 로

지금은 커스텀 스킴(`weddingplant://share/{code}`)으로만 열린다.
`com.apple.developer.associated-domains` + 웹 서버의 `apple-app-site-association`
가 필요하다.
