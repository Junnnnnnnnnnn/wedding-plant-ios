# Mac 에서 구동하기

Mac 이 생기면 이 프로젝트의 제약 대부분이 사라진다. 이 문서는 (1) Mac 을 어떻게 확보할지,
(2) 확보한 Mac 에서 무엇을 하면 되는지를 다룬다.

---

## 1. Mac 이 있으면 달라지는 것

| | Windows (현재) | Mac |
| --- | --- | --- |
| SwiftUI 컴파일 | **불가** | 즉시 |
| 시뮬레이터 | **불가** | 실시간 조작 |
| 화면 확인 루프 | CI 왕복 **15~25분** | **몇 초** |
| SwiftUI Preview | 불가 | 코드 옆에서 실시간 |
| 디버거 · Instruments | 불가 | 전부 가능 |
| 내 아이폰에 설치 | Sideloadly(7일) 또는 TestFlight($99) | **무료 Apple ID + USB 로 바로** |
| Core 유닛테스트 | 가능 (환경 스크립트 필요) | 가능 (`swift test` 그대로) |

특히 마지막 줄이 크다. **Mac + 무료 Apple ID 면 $99 없이 내 아이폰에 바로 설치된다.**
Xcode 에서 아이폰을 연결하고 Cmd+R 만 누르면 된다. (인증서가 7일마다 만료되는 건 Sideloadly 와 동일하지만,
재설치가 Cmd+R 한 번이라 부담이 다르다.)

---

## 2. Mac 확보 방법

### 중요: 클라우드 Mac 은 내 아이폰에 설치할 수 없다

클라우드 Mac 은 원격 서버라 **내 책상의 아이폰을 USB 로 연결할 수 없다.**
클라우드 Mac 으로 할 수 있는 건 **시뮬레이터까지**다. 실기기 설치를 원하면
물리적인 Mac 을 사거나, TestFlight($99) 경로로 가야 한다.

| 방법 | 대략 비용 | 시뮬레이터 | 내 아이폰 설치 | 비고 |
| --- | --- | --- | --- | --- |
| **중고 Mac mini M1** (8GB/256GB) | 40~70만원 (1회) | O | **O** | 가성비 최고. 원격 데스크톱으로 Windows 에서 씀 |
| **신품 Mac mini M4** (16GB/256GB) | 80만원대 (1회) | O | **O** | 램 16GB. 오래 쓸 거면 이쪽 |
| **MacinCloud** | 월 $25~50 | O | X | 진입이 제일 쉬움. RDP 접속 |
| **Scaleway Mac mini** | 시간당이나 **최소 24시간 청구** | O | X | 장기 임대 시 저렴. VNC |
| **AWS EC2 Mac** | **최소 24시간 청구**, 비쌈 | O | X | 기업 CI 용도 |
| 맥북 빌리기 / 회사 장비 | - | O | O | 가능하면 가장 빠름 |

가격은 변하므로 구매 전 확인할 것.

**추천:** 이 앱을 계속 만들 거라면 **중고 Mac mini M1 구매**가 가장 합리적이다.
클라우드 Mac 12~18개월치 비용이면 사고, 실기기 설치까지 되고, 나중에 CI 없이도 TestFlight 업로드가 된다.
"한두 번 화면만 확인" 목적이면 MacinCloud 를 며칠 빌리는 게 싸다.

### 사양 기준

- **Apple Silicon(M1 이상) 권장.** Intel Mac 도 Xcode 16 이 돌긴 하지만(macOS 14.5+ 필요, 2019년 이후 모델) 느리다.
- **RAM 16GB 권장**, 8GB 도 가능하지만 Xcode + 시뮬레이터를 동시에 돌리면 빡빡하다.
- **저장공간**: Xcode 만 15GB 이상, 시뮬레이터 런타임 포함하면 40GB 는 잡아두는 게 좋다. 256GB 모델이면 관리가 필요하다.

---

## 3. Mac 에서 프로젝트 열기

### 3-1. Xcode 설치

App Store 에서 **Xcode** 설치 (10GB 이상, 회선에 따라 30분~2시간).
설치 후 **한 번 실행해서** 라이선스 동의와 추가 컴포넌트 설치를 끝낸다.

### 3-2. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3-3. 클론 + 실행

```bash
git clone https://github.com/<계정>/wedding-plant-ios.git
cd wedding-plant-ios
./scripts/mac-setup.sh
```

스크립트가 하는 일:

1. Xcode / Command Line Tools 상태 확인
2. XcodeGen 설치 (없으면)
3. `swift test --package-path Core` — Core 82개 테스트 실행
4. `xcodegen generate` — `project.yml` 로부터 `.xcodeproj` 생성
5. Xcode 열기

**`.xcodeproj` 는 저장소에 없다.** Windows 에서 만들 수 없어 커밋하지 않고, `project.yml` 로부터 매번 생성한다.
프로젝트 구조를 바꿀 일이 있으면 `.xcodeproj` 가 아니라 `project.yml` 을 고치고 `xcodegen generate` 를 다시 돌린다.
(Xcode 에서 파일을 추가해도 `project.yml` 은 자동으로 안 바뀐다 — 소스는 폴더 기준으로 잡히므로
파일 추가는 그냥 되지만, 타깃/설정 변경은 반드시 `project.yml` 에 반영할 것.)

### 3-4. 시뮬레이터에서 실행

Xcode 상단에서 기기를 **iPhone 16** 등 시뮬레이터로 고르고 **Cmd+R**.

데모 데이터로 채워진 화면을 보려면 실행 인자를 준다:

- Product → Scheme → Edit Scheme → Run → Arguments
- **Arguments Passed On Launch** 에 `-WPDemoMode` 추가

이러면 백엔드 없이 이름 "지수", 예산 5000만원, 일정 6개가 채워진 화면이 뜬다.
빼면 실제 백엔드(`API_BASE_URL`, 기본 `http://localhost:3111`)에 붙는다.

### 3-5. UI 테스트 / 스크린샷

**Cmd+U** — CI 가 돌리는 것과 같은 스크린샷 테스트가 로컬에서 실행된다.
결과는 Report navigator(Cmd+9)에서 확인한다.

### 3-6. 내 아이폰에 설치 (무료 Apple ID)

1. Xcode → Settings → **Accounts** 에 본인 Apple ID 추가 (무료 계정으로 충분)
2. 아이폰을 USB 로 연결 → 아이폰에서 "이 컴퓨터를 신뢰"
3. Xcode → 프로젝트 → **WeddingPlant** 타깃 → **Signing & Capabilities**
   - 서명 방식은 `project.yml` 에서 이미 **Automatic** 이다. **Team 만 고르면 된다.**
   - Bundle Identifier `com.zipshowkorea.weddingplant` 가 다른 팀에 등록돼 있어 거부되면
     뒤에 본인 식별자를 붙인다 (예: `com.zipshowkorea.weddingplant.jisoo`)
4. 상단 기기 목록에서 연결된 아이폰 선택 → **Cmd+R**
5. 아이폰: **설정 → 일반 → VPN 및 기기 관리 → 본인 Apple ID → 신뢰**

제약은 Sideloadly 와 같다 — **7일 만료**, 동시 3개, 푸시 알림 불가.
다만 재설치가 Cmd+R 한 번이라 실사용에 무리가 없다.

> **Team 선택은 생성된 `.xcodeproj` 에만 남는다.** `xcodegen generate` 를 다시 돌리면 초기화된다.
> 매번 고르기 귀찮으면 `project.yml` 의 `DEVELOPMENT_TEAM: ""` 에 본인 팀 ID(10자리)를 박아두면 된다.
> Xcode → Settings → Accounts → 팀 선택 후 우측에 표시되거나, 서명 성공 후
> `Signing & Capabilities` 탭에서 확인할 수 있다.

---

## 4. Mac 이 생기면 정리할 것

- **CI 는 계속 쓴다.** 로컬 확인이 빨라져도, `main` 에 올라간 코드가 깨끗한지 확인하는 용도로 유지한다.
  다만 `ios.yml` 의 시뮬레이터 캡처 job 은 macOS 분을 많이 먹으니 `workflow_dispatch` 전용으로 돌리거나
  `pull_request` 에서만 돌리도록 줄이는 걸 고려한다.
- **Xcode Cloud** 가 선택지에 들어온다. Apple Developer Program 가입 시 월 25시간 무료이고,
  서명을 Apple 이 알아서 처리해 GitHub Actions 서명 설정이 통째로 필요 없어진다.
  단 최초 워크플로 생성에 Xcode 가 필요해서 지금까지는 쓸 수 없었다.
- **Windows 쪽 Core 개발은 그대로 유효하다.** 로직을 Core 에 밀어 넣는 구조는 Mac 이 생겨도 좋은 설계다
  (테스트가 빠르고, UI 없이 검증되므로). `scripts/swift-env.ps1` 도 그대로 둔다.

---

## 5. 지금 결정이 필요한 것

Mac 을 구할 계획이 확실하면 **impeccable 디자인 패스를 Mac 에서 하는 게 낫다.**
시뮬레이터를 보면서 고치는 것과, CI 스크린샷을 15~25분마다 받아보며 고치는 것은 품질 차이가 크다.

Mac 확보가 불확실하거나 시간이 걸리면, 그 사이에 Windows 에서 할 수 있는 것:

- Core 로직 확장 (일정 CRUD, 카테고리, 채팅 도메인) — 유닛테스트로 전부 검증 가능
- 백엔드 API 스펙 확인 및 `Endpoint.swift` 채우기
- Apple Developer Program 가입 (승인 대기가 있으니 미리)
