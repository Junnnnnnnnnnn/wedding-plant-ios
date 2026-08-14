# 현재 상태 / 인수인계

마지막 갱신: 2026-08-14 (Windows 세션 → Mac 세션 인계 시점)

여기까지의 배경은 `CLAUDE.md` 를 먼저 읽을 것. 이 문서는 **지금 어디까지 됐고 다음에 뭘 할지**만 다룬다.

---

## 한 줄 요약

Core 로직과 주요 화면(랜딩·메인·설정 6단계·하단 탭)을 웹 디자인에 맞춰 구현했고,
CI 에서 시뮬레이터 빌드·스크린샷까지 통과한 상태다. 나머지 화면과 기능이 남았다.

- 저장소: <https://github.com/Junnnnnnnnnnn/wedding-plant-ios> (**공개**)
- Core 테스트: 102개 통과 (Windows/Linux 에서 실행 가능)
- SwiftUI: CI 시뮬레이터 빌드 통과, 스크린샷으로 육안 확인 완료

---

## 화면별 상태

| 화면 | 웹 라우트 | 상태 |
| --- | --- | --- |
| 랜딩 | `/` | **웹과 1:1** (로고 카드, 48pt 타이틀, 2색 부제, 카카오 버튼) |
| 설정 6단계 | `/setting` | **웹과 1:1** (축하→날짜→예산→이름→환영→약관). 단, 3D 출입증(Lanyard) 단계는 웹에도 있으나 미포팅 |
| 메인 | `/main` | **웹과 1:1** (이름·멤버·D-Day·그라데이션 예산 카드·정렬/추가 버튼·계획중/완료 탭·카드 리스트) |
| 하단 탭바 | `BottomTabBar` | **웹과 1:1** (4탭, 피드는 준비중 알림) |
| 참여 플랜 | `/plan-list` | **팔레트·글꼴만 맞춤.** 배치는 안드로이드 `PlanListScreen.kt` 와 1:1 대조 전 |
| Settings | `/user` | **팔레트·글꼴만 맞춤.** 안드로이드 `UserScreen.kt` 와 1:1 대조 전 |
| 일정 추가 | `/add-plen` | **없음** (카카오맵 SDK 필요) |
| 예산 상세 | `/budget-detail` | **없음** (차트 필요) |
| 일정 상세 | `/schedule-detail` | **없음** |
| 캘린더 | `/calendar` | **없음** |
| 채팅 | `/chat/[id]` | **없음** (SSE/APNs 필요) |
| 공유 링크 | `/share/[code]` | **없음** (Universal Links 필요) |

## 동작하지 않는 UI (모양만 있음)

메인 화면의 아래 요소는 웹에 맞춰 그려뒀지만 탭해도 아무 일도 없다.

- 정렬 버튼("시작 ↓") — 웹은 정렬 모달
- 추가 버튼("추가 ⊕") — 웹은 `/add-plen` 으로 이동
- 도움말 아이콘("?") — 웹은 가이드 오버레이
- 초대 버튼 — 웹은 공유 링크 생성
- 캘린더 아이콘 — 웹은 `/calendar` 로 이동

---

## 다음에 할 일 (우선순위)

### 1. `PlanListView` / `UserView` 를 안드로이드와 1:1 대조

가장 값싸고 눈에 띄는 작업. `ui/planlist/PlanListScreen.kt`(8KB), `ui/user/UserScreen.kt`(8KB) 를 읽고 맞춘다.

### 2. 카카오 로그인 실연동

지금은 랜딩의 카카오 버튼이 데모에서만 통과된다. 실제로는:

```
Kakao SDK 로그인 → access token → POST /plan/auth/kakao/login { accessToken } → 앱 JWT → Keychain
```

- SwiftPM 에 `https://github.com/kakao/kakao-ios-sdk` 추가 (`project.yml` 의 `packages`)
- 카카오 개발자 콘솔에 **iOS 플랫폼 + Bundle ID** 등록
- `Info.plist`: `CFBundleURLSchemes = kakao{NATIVE_APP_KEY}`,
  `LSApplicationQueriesSchemes = [kakaokompassauth, kakaolink]`
- **네이티브 앱 키**를 쓴다. 웹의 JavaScript 키/REST API 키가 아니다.
  키는 `Config/Local.xcconfig` 로 주입하고 커밋하지 않는다
- 로그인 후 분기는 이미 Core 에 있다 → `PostLoginRouter.destination(for:)` (전 분기 유닛테스트 완료)
- 게스트 데이터 마이그레이션도 Core 에 있다 → `GuestMigration`

### 3. 남은 화면

`/add-plen` 이 가장 크다(웹 78KB). 카카오맵 iOS SDK(`KakaoMapsSDK`) 또는 MapKit 결정 필요.

### 4. 백엔드에 요청해야 하는 것

- **APNs 디바이스 토큰 등록 API.** iOS 는 백그라운드에서 SSE 를 유지하지 못하므로
  웹의 `EventSource` 알림 방식을 그대로 쓸 수 없다. 채팅/알림의 선행 조건이다.

### 5. 배포

- Apple Developer Program 가입 (미가입 상태). 승인에 며칠 걸리니 미리
- 가입되면 `docs/INSTALL_ON_IPHONE.md` 의 A 경로 + `scripts/setup-signing.ps1`
- Mac 이 있으므로 무료 Apple ID + USB 로도 설치 가능 → `docs/RUN_ON_MAC.md` §3-6

---

## Mac 에서 이어서 할 때

```bash
git pull
./scripts/mac-setup.sh     # xcodegen generate 포함
```

1. `.claude/skills/` 가 없으면 `PERSONAL/wedding-plant/.claude/skills/` 에서 복사
   (`hallmark`, `impeccable`. 저장소가 공개라 커밋하지 않는다)
2. `Config/Local.xcconfig` 가 없으면 `cp Config/Local.example.xcconfig Config/Local.xcconfig`
   후 실제 API 주소 입력. **xcconfig 에서 `//` 는 주석이라 `https:/$()/...` 로 써야 한다**
3. 스킴을 `WeddingPlant (Demo)` 로 두고 Cmd+R 이 가장 빠른 확인 경로

### Windows 쪽은 계속 유효하다

Core 는 Windows 에서 그대로 빌드·테스트된다(`.\scripts\test.ps1`). 로직 작업은 어느 쪽에서 해도 된다.
UI 만 Mac 이 필요하다. CI 도 그대로 두는 게 좋다 — `main` 이 깨지지 않았는지 확인하는 용도.

다만 Mac 이 생겼으니 `ios.yml` 의 시뮬레이터 캡처 job 을 매 push 마다 돌릴 필요는 줄었다.
macOS 러너 분을 아끼려면 `workflow_dispatch` 전용이나 `pull_request` 한정으로 줄이는 것을 검토한다.
(현재 저장소가 공개라 Actions 는 무료 무제한이므로 급하지는 않다)

---

## 최근에 고친 것 (같은 실수 반복 방지)

전부 `CLAUDE.md` 의 "하드 트랩" 표에 정리해뒀다. 요약:

- `Font.custom` 은 PostScript 이름 필요 → TTF name 테이블에서 추출
- `Text("\(Int)")` 로케일 포맷 → `Text(verbatim:)`
- 앱 로케일 `ko` 고정 안 하면 DatePicker 가 영어
- `roomId` 있으면 일정·금액 경로가 방 기준으로 바뀜
- `accessibilityIdentifier` 는 `Button` 자체에 붙여야 UI 테스트가 잡음
- 카테고리 색은 JS Int32 오버플로 해시를 그대로 재현해야 함
