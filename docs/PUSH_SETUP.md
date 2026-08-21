# 푸시 알림(백그라운드) 설정

앱이 **꺼져 있거나 백그라운드일 때** 채팅 알림을 받기 위한 설정.

앱을 켜고 그 채팅방을 보고 있을 때는 소켓이 배달하므로 이 설정이 필요 없다
(→ `docs/TEST_CHAT_ON_DEVICE.md`).

---

## 먼저 알아야 할 것

**유료 Apple Developer Program($99/년)이 없으면 푸시는 동작하지 않는다.**
무료 Apple ID 로는 Push Notifications capability 자체가 서명되지 않는다 —
코드가 아니라 애플의 제약이다.

그래서 엔타이틀먼트를 **꺼진 상태로 커밋**해 두었다. 무료 계정으로도 지금처럼
실기기 설치·소켓 채팅 확인이 그대로 된다. 유료 계정이 준비되면 한 줄로 켠다.

---

## 1. 백엔드 — iOS 용 페이로드 수정이 필요하다

현재 백엔드는 `notification` 없이 `data` 만 보낸다:

```json
{ "chatRoomId": "1", "senderName": "신부", "body": "안녕하세요" }
```

안드로이드는 이걸로 앱이 직접 알림을 만들지만, **iOS 에서 data-only 는 무음 푸시**다.
배너가 뜨지 않고, 전송도 보장되지 않으며, 앱이 종료돼 있으면 깨우지도 못한다.

iOS 대상에는 알림 본문을 함께 실어야 한다:

```json
{
  "token": "<FCM 등록 토큰>",
  "data": { "chatRoomId": "1", "senderName": "신부", "body": "안녕하세요" },
  "apns": {
    "payload": {
      "aps": {
        "alert": { "title": "신부", "body": "안녕하세요" },
        "sound": "default"
      }
    }
  }
}
```

`data` 는 **그대로 둬야 한다.** 알림을 눌렀을 때 `chatRoomId` 로 채팅방을 찾아간다.

> 안드로이드는 지금 모양 그대로 두면 된다. 플랫폼별로 갈라 보내면 된다.

## 2. Apple Developer 콘솔

1. Apple Developer Program 가입
2. Identifiers → App ID `com.zipshowkorea.weddingplant` 등록 → **Push Notifications** 체크
3. Keys → **APNs Auth Key(.p8)** 생성 → 다운로드 (한 번만 받을 수 있다)
   - Key ID 와 Team ID 를 함께 적어 둔다
   - **`.p8` 은 저장소에 넣지 않는다** (`.gitignore` 에 이미 있다)

## 3. Firebase 콘솔

1. 기존 프로젝트(안드로이드와 같은 것)에 **iOS 앱 추가**
   - 번들 ID: `com.zipshowkorea.weddingplant`
2. `GoogleService-Info.plist` 다운로드 → **`App/Resources/Firebase/`** 에 둔다
   - 넣은 뒤 `xcodegen generate` 를 다시 돌려야 번들에 들어간다
   - 저장소가 공개라 `.gitignore` 되어 있다. 각자 받아서 두면 된다
3. 프로젝트 설정 → 클라우드 메시징 → **APNs 인증 키 업로드**
   - 2번에서 받은 `.p8` + Key ID + Team ID

## 4. 앱 쪽 켜기

`Config/Local.xcconfig` 에 한 줄:

```
WP_ENTITLEMENTS = App/Resources/WeddingPlant.entitlements
```

그리고 `xcodegen generate` 후 다시 빌드.

> TestFlight·App Store 배포 빌드는 `aps-environment` 를 `production` 으로 바꿔야 한다.
> `App/Resources/WeddingPlant.entitlements` 참고.

---

## 동작 방식

| 상황 | 동작 |
| --- | --- |
| 앱 종료·백그라운드 | 시스템 배너. 누르면 그 채팅방이 열린다 |
| 앱 켜짐, 다른 화면 | 배너 대신 **인앱 토스트** (배너까지 뜨면 두 번 알리는 셈) |
| 앱 켜짐, **그 채팅방을 보는 중** | 아무것도 안 띄운다 (소켓으로 이미 화면에 떴다) |

판단 규칙은 `PushRouting`(Core)에 있고 테스트로 고정돼 있다.

**토큰 등록 시점**

- 토큰이 갱신될 때마다
- **로그인 직후에도 한 번** — 설치 후 첫 로그인에는 갱신 콜백이 오지 않는다.
  갱신 때만 등록하면 새로 깐 기기에 알림이 영영 안 온다
- 로그아웃 시 해제. **JWT 를 지우기 전에** 부른다(`DELETE` 에 `Authorization` 이 필요하다).
  안 하면 로그아웃해도 그 기기로 알림이 계속 간다 — 기기를 넘기거나 공용 기기면
  남의 채팅 내용이 그대로 뜬다

**FCM 이 없으면**

`GoogleService-Info.plist` 가 없으면 Firebase 를 켜지 않고 **APNs 원시 토큰**을
같은 엔드포인트로 보낸다. 백엔드가 APNs 로 직접 쏘는 구성이면 그대로 동작한다.
어느 쪽을 쓰는지는 Xcode 콘솔에서 `WPPush` 로 필터하면 보인다.

---

## 확인 순서

1. 실기기에서 로그인 → 알림 권한 허용
2. Xcode 콘솔 `WPPush` 필터 → `FCM 활성화` + `기기 토큰 등록 완료`
3. Firebase 콘솔 → Messaging → 테스트 메시지를 그 토큰으로 전송
4. 앱을 **완전히 종료**한 뒤 안드로이드에서 메시지 전송 → 배너 확인
5. 배너를 눌러 해당 채팅방이 열리는지 확인

### 안 될 때

| 증상 | 원인 |
| --- | --- |
| `원격 알림 등록 실패 ... aps-environment` | 유료 계정이 아니거나 `WP_ENTITLEMENTS` 미설정 |
| 토큰은 나오는데 배너가 안 뜸 | 백엔드가 `data` 만 보내는 중 (1번) |
| Firebase 테스트 메시지는 오는데 백엔드 것만 안 옴 | 백엔드가 iOS 토큰을 다른 방식으로 보내는지 확인 |
| 앱 켜져 있을 때만 안 뜸 | 정상이다. 토스트로 대체된다 |
