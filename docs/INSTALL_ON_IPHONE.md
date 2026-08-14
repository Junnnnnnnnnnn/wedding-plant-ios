# 아이폰에 설치하기 (Mac 없이)

두 가지 경로가 있다. 둘 다 Mac 없이 Windows 에서 가능하다.

| | **A. TestFlight** | **B. Sideloadly (무료)** |
| --- | --- | --- |
| 비용 | **$99/년** (Apple Developer Program) | 무료 |
| 준비 시간 | 가입 승인 1~2일 + 설정 1시간 | 30분 |
| 설치 방법 | 아이폰에서 무선으로 | **USB 케이블로 PC 연결** |
| 유효기간 | 빌드당 90일 | **7일** — 만료되면 재설치 |
| 앱 개수 제한 | 없음 | 무료 계정은 동시 3개 |
| 업데이트 | 푸시하면 알아서 | 매번 케이블 연결 |
| 다른 사람에게 배포 | 최대 10,000명 | 불가 |
| 푸시 알림(APNs) | 가능 | **불가** (무료 프로비저닝 제한) |

**권장: B로 먼저 확인하고, 계속 갈 것 같으면 A로 넘어간다.**
B는 오늘 안에 손에 들 수 있고, A는 결제와 승인 대기가 있다. 나중에 APNs 를 붙이려면 A가 필수다.

두 경로 모두 워크플로는 이미 준비돼 있다 — `.github/workflows/device.yml`.

---

## 공통 전제 — 백엔드 주소

**이걸 먼저 하지 않으면 앱은 설치돼도 데이터가 안 나온다.**

앱의 기본 백엔드 주소는 `Config/Base.xcconfig` 의 `http://localhost:3111` 이다.
아이폰에서 `localhost` 는 아이폰 자신을 가리키므로 아무 데도 연결되지 않는다.

이 저장소는 공개이므로 실제 API 주소를 커밋하지 않는다. 대신 **GitHub Secret 으로 주입**한다.

```powershell
gh secret set API_BASE_URL --body "https://실제-api-도메인"
```

워크플로가 빌드 시 이 값을 주입한다. 시크릿이 없으면 경고를 남기고 localhost 로 빌드된다.

로컬(Xcode)에서 빌드할 때는 `Config/Local.xcconfig` 에 적는다 (gitignore 됨):

```
API_BASE_URL = https:/$()/실제-api-도메인
```

> xcconfig 에서 `//` 는 주석이라 URL 은 `$()` 로 끊어 써야 한다.

## GitHub 저장소

아직 없으면:

```
! gh auth login
```

```powershell
cd <저장소 폴더>
git add -A
git commit -m "feat: iOS 앱 스켈레톤 + 배포 파이프라인"
gh repo create wedding-plant-ios --private --source=. --remote=origin --push
```

---

# A. TestFlight

## A-1. Apple Developer Program 가입

<https://developer.apple.com/programs/enroll/>

- 연 $99 (약 14만원). **개인(Individual)** 으로 가입하면 D-U-N-S 번호가 필요 없어 간단하다.
- Apple ID 에 2단계 인증이 켜져 있어야 한다.
- 개인 가입은 보통 24~48시간 내 승인. **지금 시작해 두는 게 좋다.**
- 조직(Organization)으로 가입하면 D-U-N-S 번호가 필요하고 몇 주 걸릴 수 있다.

승인 메일이 오기 전까지는 아래를 진행할 수 없다.

## A-2. 인증서 만들기 (Windows 에서)

Mac 없이 openssl 로 만든다. Git for Windows 에 openssl 이 들어 있다.

```powershell
.\scripts\setup-signing.ps1 -Step csr -Email "<애플ID 이메일>" -CommonName "<이름 또는 조직명>"
```

`signing\ios_dist.csr` 이 생긴다. 브라우저에서:

1. <https://developer.apple.com/account/resources/certificates/list>
2. `+` → **Apple Distribution** → 방금 만든 `.csr` 업로드
3. `distribution.cer` 다운로드 → `signing\distribution.cer` 로 저장

그다음:

```powershell
.\scripts\setup-signing.ps1 -Step p12 -Password "직접정한강한비밀번호"
```

`signing\distribution.p12` 가 만들어진다.

## A-3. App ID · 프로비저닝 프로파일

1. **Identifiers** → `+` → App IDs → App
   - Bundle ID: `com.zipshowkorea.weddingplant` (Explicit)
   - Capability 는 지금 아무것도 필요 없다. 나중에 푸시를 붙일 때 Push Notifications 를 켠다.
2. **Profiles** → `+` → Distribution → **App Store Connect**
   - App ID: 위에서 만든 것
   - Certificate: 위에서 만든 Apple Distribution
   - 이름은 아무거나 (워크플로가 프로파일에서 자동으로 읽는다)
   - 다운로드 → `signing\profile.mobileprovision` 로 저장

## A-4. App Store Connect API 키

<https://appstoreconnect.apple.com/access/integrations/api>

1. `+` → Access: **App Manager** → 생성
2. `AuthKey_XXXXXXXX.p8` 다운로드 → `signing\` 에 저장
   - **재다운로드 불가.** 잃어버리면 키를 새로 만들어야 한다.
3. 같은 화면에서 **Key ID** 와 **Issuer ID** 를 메모

## A-5. 앱 레코드 생성

<https://appstoreconnect.apple.com/apps> → `+` → 새로운 앱

- 플랫폼: iOS
- 이름: 웨딩플랜 (App Store 전체에서 고유해야 함)
- 기본 언어: 한국어
- 번들 ID: `com.zipshowkorea.weddingplant`
- SKU: 아무 문자열 (예: `weddingplant-ios`)

## A-6. GitHub Secrets 등록

```powershell
.\scripts\setup-signing.ps1 -Step secrets `
  -Password "A-2에서 정한 비밀번호" `
  -AscKeyId "ABCD123456" `
  -AscIssuerId "69a6de00-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

6개가 자동 등록된다: `IOS_DIST_P12_BASE64`, `IOS_DIST_P12_PASSWORD`,
`IOS_PROVISION_PROFILE_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`.

## A-7. 빌드 · 업로드

```powershell
gh workflow run device.yml -f mode=testflight
gh run watch
```

15~25분 뒤 업로드 완료. App Store Connect 가 처리하는 데 추가로 10~30분 걸린다.

## A-8. 아이폰에 설치

1. App Store Connect → 내 앱 → **TestFlight** 탭에 빌드가 나타난다
2. **Internal Testing** 그룹 생성 → 본인 Apple ID 추가
   - 내부 테스트는 **심사 없이 즉시** 설치 가능 (최대 100명)
   - 외부 테스트(최대 10,000명)는 첫 빌드에 베타 심사가 붙는다 (보통 1일 내)
3. 아이폰 App Store 에서 **TestFlight** 앱 설치
4. 초대 메일의 링크를 아이폰에서 열기 → 설치

수출 규정 질문은 `Info.plist` 에 `ITSAppUsesNonExemptEncryption: false` 를 넣어둬서 매번 뜨지 않는다.

이후 업데이트는 `gh workflow run device.yml -f mode=testflight` 만 다시 돌리면 된다.
빌드 번호는 워크플로 실행 번호를 쓰므로 중복 걱정이 없다.

---

# B. Sideloadly (무료, 케이블 연결)

Apple 개발자 계정 없이, 평범한 무료 Apple ID 로 아이폰에 설치한다.

## B-1. 서명 없는 .ipa 받기

```powershell
gh workflow run device.yml -f mode=unsigned-ipa
gh run watch
gh run download --name unsigned-ipa --dir .\ipa
```

`ipa\WeddingPlant-unsigned.ipa` 가 생긴다.

## B-2. Windows 준비

1. **Apple Devices** 또는 **iTunes** 설치 — Sideloadly 가 아이폰과 통신하는 데 필요하다
   - Microsoft Store 판 iTunes 는 인식이 안 될 때가 있다. 문제가 생기면 apple.com 에서 받은 데스크톱 버전을 쓴다.
2. **Sideloadly** 설치: <https://sideloadly.io>
3. 아이폰을 USB 로 연결하고, 아이폰에서 **"이 컴퓨터를 신뢰"** 를 누른다

## B-3. 설치

1. Sideloadly 실행 → 연결된 아이폰이 목록에 뜨는지 확인
2. `.ipa` 파일을 창에 드래그
3. Apple ID 입력 (평범한 무료 계정으로 충분)
4. **Start** → 2단계 인증 코드를 물어보면 입력
5. 설치가 끝나면 아이폰에서:
   **설정 → 일반 → VPN 및 기기 관리 → 본인 Apple ID → 신뢰**
6. 홈 화면에서 앱 실행

## B-4. 제약 (반드시 알고 시작할 것)

- **7일마다 만료된다.** 만료되면 앱이 실행되지 않고, B-3 을 다시 해야 한다.
  (Sideloadly 의 유료 기능이나 SideStore 로 무선 갱신을 자동화할 수는 있다)
- 무료 계정은 **동시에 3개**까지만 사이드로드 가능
- **푸시 알림(APNs), App Groups, iCloud 를 쓸 수 없다.** 무료 프로비저닝 제한이다.
  지금 앱은 이 기능들을 안 쓰므로 문제없지만, 알림을 붙이는 순간 A 로 넘어가야 한다.
- 번들 ID 가 Sideloadly 에 의해 바뀔 수 있다 (정상 동작)
- 다른 사람에게 나눠줄 수 없다

---

## 지금 앱에서 확인할 수 있는 것

설치하면 데모 데이터가 아니라 **실제 백엔드에 붙는다.** 기본 주소는 `http://localhost:3111` 인데,
아이폰에서 localhost 는 아이폰 자신을 가리키므로 연결되지 않는다. 둘 중 하나를 하라:

- **PC 의 로컬 IP 를 쓴다** — `project.yml` 의 `API_BASE_URL` 을 `http://192.168.0.x:3111` 로 지정하고
  (`Info.plist` 의 `NSAllowsLocalNetworking` 은 이미 켜져 있다) 아이폰과 PC 를 같은 Wi-Fi 에 둔다
- **배포된 백엔드 주소를 쓴다** — 운영 서버가 있으면 그쪽을 가리킨다

백엔드 없이 화면만 보고 싶으면 데모 모드로 빌드해야 하는데, 실기기에서는 실행 인자를 줄 수 없으므로
`AppEnvironment.bootstrap()` 의 `isDemo` 판정에 빌드 설정을 하나 추가해야 한다. 필요하면 말해 달라.

현재 구현된 화면: 온보딩 / 초기 설정 / 메인(D-day·예산·일정) / 참여 플랜 / 설정 탭.
아직 없는 것: 일정 추가, 예산 상세, 채팅, 공유 링크, 캘린더, 카카오 로그인 실연동.

---

## 잘 안 될 때

| 증상 | 원인 / 해결 |
| --- | --- |
| CI 에서 `security import` 실패 | `.p12` 가 OpenSSL 3 기본 방식으로 만들어진 경우. `-Step p12` 를 다시 실행 (`-legacy` 로 재생성) |
| `No profiles for 'com.zipshowkorea...' were found` | Bundle ID 와 프로파일이 안 맞음. A-3 에서 Explicit App ID 로 만들었는지 확인 |
| TestFlight 에 빌드가 안 보임 | 처리에 10~30분. 그 뒤에도 없으면 Apple 에서 온 거부 메일 확인 |
| `Invalid build number` | 이미 쓴 빌드 번호. 워크플로를 다시 돌리면 실행 번호가 올라가 해결된다 |
| Sideloadly 가 아이폰을 못 찾음 | iTunes/Apple Devices 미설치, 또는 "이 컴퓨터를 신뢰"를 안 누름. 케이블도 데이터 전송용인지 확인 |
| 앱이 실행되자마자 종료 | 아이폰 설정에서 개발자 인증서를 신뢰했는지 확인 (B-3 5번) |
| 앱은 뜨는데 데이터가 안 나옴 | 백엔드 주소 문제. 위 "지금 앱에서 확인할 수 있는 것" 참고 |
