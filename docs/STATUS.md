# 현재 상태 / 인수인계

마지막 갱신: 2026-08-20

배경은 `CLAUDE.md` 를 먼저 읽을 것. 이 문서는 **지금 어디까지 됐고 다음에 뭘 할지**만 다룬다.

> **작업 전에 반드시 읽을 것: `wedding-plant-android/docs/IOS_PORTING_NOTES.md`**
> 안드로이드 팀이 iOS 를 위해 남긴 문서. 코드만 봐서는 모르는 백엔드 함정이 정리돼 있다.
> 여기 있는 항목은 이미 `CLAUDE.md` 의 "절대 틀리면 안 되는 것" 표에 반영했다.

---

## 한 줄 요약

안드로이드 앱은 **완성**됐고(65개 파일), iOS 는 그 절반쯤 왔다.
**웹의 화면은 전부 이식했다.** 남은 건 카카오 로그인 실연동 · 인앱 알림(SSE) · 푸시 · 배포다.

- 저장소: <https://github.com/Junnnnnnnnnnn/wedding-plant-ios> (**공개**)
- Core 테스트: **234개 통과** (Windows/Linux)
- SwiftUI: CI 시뮬레이터 빌드 통과, 스크린샷으로 육안 확인

---

## 화면별 상태

| 화면 | 웹 라우트 | 상태 |
| --- | --- | --- |
| 랜딩 | `/` | **웹과 1:1** |
| 설정 6단계 | `/setting` | **웹과 1:1** (축하→날짜→예산→이름→환영→약관). 웹의 3D 출입증(Lanyard) 단계만 미포팅 |
| 메인 | `/main` | **웹과 1:1** + 정렬 시트 동작 |
| 하단 탭바 | `BottomTabBar` | **웹과 1:1** (4탭, 피드는 준비중 알림) |
| 참여 플랜 | `/plan-list` | **웹과 1:1** (Room #N, 왕관 뱃지, 채팅방 행, 남은 예산 진행바) |
| Settings | `/user` | **웹과 1:1** (프로필 수정·저장 상태·로그아웃 확인) |
| 일정 상세 | `/schedule-detail` | **웹과 1:1**. 단 지도 임베드는 없고 "카카오맵에서 보기" 링크만 |
| 일정 추가/수정 | `/add-plen` | **웹과 1:1** (제목→카테고리→금액 단계 노출, 추천 칩, 게스트 3개 제한). 장소 검색은 백엔드 부재로 안내만 |
| 예산 상세 | `/budget-detail` | **웹과 1:1** (통계 카드·AI 안내·카테고리 막대·예정/사용 탭·게스트 블러) |
| 캘린더 | `/calendar` | **웹과 1:1** (42칸 격자, 달 이동, 날짜별 시트, 읽기 권한이면 추가 버튼 숨김) |
| 채팅 | `/chat/[id]` | **웹과 1:1** (Socket.IO 직접 구현, 무제한 재연결, 날짜 구분선·일정 카드·이름 변경) |
| 공유 참여 | `/share/[code]` | **웹과 1:1** (자동 참여 → 참여 플랜 목록, 비로그인이면 코드를 남기고 로그인 안내) |
| 인앱 알림(SSE) | `NotificationContext` | **없음**. 웹은 채팅방마다 SSE 를 열어 토스트·미읽음 배지를 띄운다 |
| 푸시(APNs) | - | **없음**. Core 에 엔드포인트·페이로드 모델만 준비됨 |

## 아직 동작하지 않는 UI (모양만 있음)

- 메인의 **도움말(?)** → 가이드 오버레이
- 예산 상세의 **도움말(?)** → 가이드 오버레이 (자리만 잡아 둠)
- 메인의 **초대** 버튼 → 공유 링크 생성

---

## 다음에 할 일 (우선순위)

### 1. 카카오 로그인 실연동

- SwiftPM 에 `kakao-ios-sdk` 추가, 카카오 콘솔에 iOS 플랫폼 + Bundle ID 등록
- 본문 키는 **`kakaoToken`** (`accessToken` 이면 400)
- **네이티브 앱 키**를 쓴다. `Config/Local.xcconfig` 로 주입하고 커밋하지 않는다
- 로그인 후 분기는 이미 Core 에 있다 → `PostLoginRouter` (전 분기 테스트 완료)
- 게스트 데이터 이관도 Core 에 있다 → `GuestMigration`

### 2. 채팅 실서버 확인 → `docs/TEST_CHAT_ON_DEVICE.md`

소켓 자체는 붙었지만 **실서버로 확인하지 못했다**(CI 시뮬레이터에는 백엔드가 없다).
안드로이드 → iOS 수신 확인 절차는 `docs/TEST_CHAT_ON_DEVICE.md` 에 정리했다.
**푸시 없이 확인 가능하다** — 앱을 켜고 그 방을 보고 있으면 소켓으로 온다.

카카오 로그인 전이라 실기기 로그인은 **개발용 토큰 붙여넣기**로 한다
(첫 화면 아래 버튼, `#if DEBUG`). 프레임 조립·해석은 `SocketIOPacketTests` 로 고정해 뒀다.
안 붙을 때는 Xcode 콘솔에서 `WPSocket` 으로 필터한다.

### 3. 인앱 알림(SSE)

웹 `NotificationContext` — 채팅방마다 `EventSource` 를 열어 토스트·미읽음 배지를 띄운다.
**읽기 타임아웃을 끄면 안 된다.** 서버가 조용히 끊었을 때 영원히 기다리게 되어,
앱은 멀쩡한데 알림만 안 오는 상태가 된다. keep-alive 주기(30초)의 3배를 타임아웃으로 둘 것.

### 4. 푸시(APNs — FCM 경유)

백엔드가 이미 FCM 이므로 iOS 도 **FCM 등록 토큰**을 같은 엔드포인트에 보내면 된다
(`platform: IOS`). Core 에 `Endpoint.registerDeviceToken/unregisterDeviceToken`,
`PushPayload` 가 있다. 남은 건 FirebaseMessaging 연동과 `UNUserNotificationCenter` 다.

필요한 것: **Apple Developer Program(유료)** → APNs 인증 키(.p8) → Firebase 콘솔 업로드 →
`GoogleService-Info.plist`(저장소가 공개라 gitignore) → Push Notifications capability.

> **백엔드 수정이 필요한 항목:** 지금은 `notification` 없이 `data` 만 보낸다.
> 안드로이드는 그걸로 앱이 직접 알림을 만들지만, **iOS 에서 data-only 는 무음 푸시**라
> 배너가 뜨지 않고 전송도 보장되지 않는다. iOS 대상에는 `notification`
> (또는 `apns.payload.aps.alert`)을 함께 실어야 한다. `data` 는 그대로 둬야
> 알림을 눌렀을 때 `chatRoomId` 로 방을 찾아갈 수 있다.

**로그아웃 시 토큰 해제는 JWT 를 지우기 전에** 해야 한다. 안 하면 로그아웃해도 알림이 계속 간다.

### 5. 공유 링크를 Universal Link 로

지금은 커스텀 스킴(`weddingplant://share/{code}`)으로만 열린다. 웹과 같은 주소로 열리게 하려면
`com.apple.developer.associated-domains` 엔타이틀먼트 + 웹 서버의 `apple-app-site-association`
파일이 필요하다. 도메인은 공개 저장소에 넣지 않으므로 `Config/Local.xcconfig` 쪽으로 뺄 것.

시뮬레이터에서 확인: `xcrun simctl openurl booted "weddingplant://share/ABC123"`

### 6. 배포

Apple Developer Program 미가입. 승인에 며칠 걸리니 미리.
Mac 이 있으므로 무료 Apple ID + USB 로도 설치 가능 → `docs/RUN_ON_MAC.md` §3-6

---

## 화면을 눈으로 확인하는 법

**프론트엔드 변경은 스크린샷을 본 뒤에 완료로 본다.** CI 통과는 컴파일됐다는 뜻일 뿐이다.

```powershell
.\scripts\preview.ps1           # 최근 성공한 CI 에서 받아 폴더 열기
.\scripts\preview.ps1 -Watch    # 지금 도는 CI 를 기다렸다 받기
```

Mac 이면 `WeddingPlant (Demo)` 스킴으로 Cmd+R 이 훨씬 빠르다.

**새 화면을 만들면 `App/UITests/ScreenshotTests.swift` 에 캡처 경로를 같이 넣을 것.**
안 넣으면 화면을 만들어도 아티팩트에 영영 안 나온다 (실제로 겪었다).

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

Core 는 Windows 에서 그대로 빌드·테스트된다(`.\scripts\test.ps1`). 로직 작업은 어느 쪽에서 해도 된다.
