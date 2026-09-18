# 현재 상태 / 인수인계

마지막 갱신: 2026-09-18

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

### 푸시 전에 돌리는 감사 둘

교차 파일 문제는 파일 단위 구문 검사로 안 잡혀 **CI 왕복을 두 번 썼다.**
그 뒤로는 푸시 전에 이 둘을 돌린다.

1. **private/internal 이름 충돌** — 파일 private 선언도 모듈 범위에서 재선언으로
   잡힌다. `SectionHeader`(UserView) 와 `ActivityShareSheet`(SettingView) 가 그랬다.
2. **모듈 심볼 사용처 ↔ import 대조** — `BrandSheet` 의 `WPUtils`,
   `FeedDetailView` 의 `WPNetworking`, `AppEnvironment` 의 `WPUtils` 가 그랬다.
   **패턴에 심볼을 빠뜨리면 감사가 통과해도 CI 가 깨진다**(`JWTDecoder` 로 겪었다).

### UI 테스트가 멈추는 함정

**끝나지 않는 애니메이션을 두지 말 것.** XCUITest 는 앱이 idle 이 될 때까지
기다린다. 뼈대 시머는 데모 모드에서 정지한다(`SkeletonBox.animated`).

---

## 다음에 할 일 (우선순위)

### 1. 카카오 콘솔에 iOS 플랫폼 등록 — **지금 막혀 있는 것**

코드는 다 붙었고 CI 빌드도 통과했다. 남은 것은 **콘솔 등록 하나**다.

- <https://developers.kakao.com> → 웨딩플랜 앱 → **앱 설정 > 플랫폼 > iOS 등록**
- 번들 ID: `com.zipshowkorea.weddingplant` (안드로이드 패키지명과 같다)
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
운영에 올릴 때 환경변수 `APPLE_BUNDLE_IDS=com.zipshowkorea.weddingplant` 를
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
