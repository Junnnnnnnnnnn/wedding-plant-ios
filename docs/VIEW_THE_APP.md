# 앱 화면 보는 법 (Mac 없이)

Windows 에서는 SwiftUI 를 컴파일조차 할 수 없다. 그래서 화면을 보려면 macOS 가 있어야 하는데,
**GitHub Actions 의 macOS 러너를 빌려 쓰면 Mac 도, Apple 개발자 계정도 없이 화면을 볼 수 있다.**

핵심은 이것이다:

> **시뮬레이터 빌드는 코드 서명이 필요 없다.**
> Apple Developer Program($99/년)이 필요한 건 **실기기 설치와 TestFlight** 뿐이다.

---

## 무엇이 나오는가

워크플로가 끝나면 Actions 실행 페이지 하단 **Artifacts** 에서 두 개를 받는다.

| 아티팩트 | 내용 |
| --- | --- |
| `app-preview` | 화면 스크린샷 PNG 여러 장 + **시뮬레이터 전체 화면 녹화 `simulator.mp4`** |
| `xcresult` | 원본 결과 번들. 스크린샷 추출이 실패했을 때의 예비책 |

동영상에는 UI 테스트가 앱을 조작하는 과정이 그대로 담긴다 —
온보딩 → 설정 입력 → 메인(D-day·예산·일정) → 참여 플랜 → 설정 탭.
정적 스크린샷보다 "어떻게 움직이는지"가 훨씬 잘 보인다.

찍히는 스크린샷:

```
01-onboarding        온보딩
02-setting           초기 설정 시트
03-setting-filled    이름 입력 후
04-main              메인 (D-92, 예산 게이지, 다가오는 일정)
05-plan-list         참여 플랜 목록
06-user              설정 탭
07-main-again        메인 복귀
```

---

## 1회 설정 (한 번만)

### 1) GitHub 로그인

터미널에 아래를 **직접** 입력한다 (브라우저 인증이 필요해 자동화할 수 없다).

```
! gh auth login
```

`GitHub.com` → `HTTPS` → `Login with a web browser` 순서로 고르면 된다.

### 2) 저장소 생성 + 푸시

```powershell
cd <저장소 폴더>

git add -A
git commit -m "feat: Core 패키지 + SwiftUI 앱 스켈레톤 + CI 미리보기 파이프라인"

gh repo create wedding-plant-ios --private --source=. --remote=origin --push
```

비공개 저장소는 Actions 무료 한도가 월 2,000분이지만 **macOS 는 10배로 소진**되어
실질 200분/월(빌드 15~20회)이다. 한도를 넘기면 과금되니 `git push` 남발은 피할 것.

---

## 가장 빠른 방법 — 스크립트 하나

```powershell
.\scripts\preview.ps1           # 최근 성공한 CI 에서 받아 폴더 열기
.\scripts\preview.ps1 -Watch    # 지금 도는 CI 가 끝날 때까지 기다렸다 받기
```

아티팩트를 내려받고, UUID 파일명을 사람이 읽을 이름(`04-main.png` 등)으로 바꾼 뒤
탐색기로 폴더를 열어 준다. `simulator.mp4` 도 같이 들어 있다.

## 2회차부터 — 화면 보고 싶을 때

```powershell
git add -A
git commit -m "설명"
git push
```

또는 코드 변경 없이 그냥 돌려보고 싶으면:

```powershell
gh workflow run ios.yml
```

진행 상황 확인:

```powershell
gh run watch          # 실시간
gh run list --limit 5 # 목록
```

끝나면 아티팩트를 내려받는다.

```powershell
gh run download --name app-preview --dir .\preview
start .\preview
```

`preview` 폴더에서 PNG 를 열어보고, `simulator.mp4` 를 재생하면 된다.
소요 시간은 한 번에 **15~25분**이다.

---

## 데모 데이터

CI 시뮬레이터는 로컬 백엔드(`:3111`)에 접근할 수 없다.
그래서 앱은 실행 인자 `-WPDemoMode` 가 있으면 `DemoTransport`(`App/Sources/Platform/DemoTransport.swift`)를
주입해 가짜 응답으로 동작한다. 화면에 보이는 이름·예산·일정이 전부 여기서 나온다.

결혼일은 **항상 오늘 + 92일**로 계산되므로, 언제 캡처해도 `D-92` 로 보인다.

화면에 다른 데이터를 띄우고 싶으면 `DemoData` 의 JSON 문자열만 고치면 된다.

---

## 실기기(내 아이폰)에서 보려면

여기까지가 계정 없이 가능한 전부다. 손에 들고 써 보려면:

1. **Apple Developer Program 가입** ($99/년, 승인에 며칠)
2. Mac 없이 인증서 만들기 — `IOS_DEV_ON_WINDOWS.md` §4 (openssl + 개발자 포털)
3. 워크플로에 아카이브 + TestFlight 업로드 job 추가 — 같은 문서 §5
4. TestFlight 내부 테스트로 초대 → 아이폰에 설치 (심사 없이 즉시)

지금 만든 `project.yml` 과 시뮬레이터 job 은 그대로 재사용된다. 추가되는 건 서명과 업로드뿐이다.

---

## 지금 구현된 화면

| 화면 | 파일 | 웹 대응 |
| --- | --- | --- |
| 온보딩 | `Features/Onboarding/OnboardingView.swift` | `/` |
| 초기 설정 | `Features/Setting/SettingView.swift` | `/setting` |
| 메인 (D-day·예산·일정) | `Features/Main/MainView.swift` | `/main` |
| 참여 플랜 | `Features/PlanList/PlanListView.swift` | `/plan-list` |
| 설정 | `Features/User/UserView.swift` | `/user` |
| 탭 셸 | `Features/Root/RootView.swift` | `BottomTabBar` |

아직 없는 것: 일정 추가(`/add-plen`), 예산 상세(`/budget-detail`), 채팅(`/chat`),
공유 링크(`/share`), 캘린더(`/calendar`), 카카오 로그인 실연동, APNs.

메인 화면의 D-day 는 Core 의 `KstDate.daysFromToday()`, 예산 게이지는 `BudgetSummary` 를
그대로 쓴다. 즉 Windows 에서 유닛테스트로 검증한 로직이 화면에 그대로 나온다.

---

## 잘 안 될 때

| 증상 | 확인할 것 |
| --- | --- |
| `simulator` job 이 컴파일 에러 | 로그의 `error:` 줄. SwiftUI 코드는 Windows 에서 검증이 불가능해 첫 실행에 한두 번 걸릴 수 있다 |
| 스크린샷이 비어 있음 | `xcresult` 아티팩트를 받아 Xcode 로 열면 실제로 무엇이 찍혔는지 볼 수 있다 |
| `simulator.mp4` 가 0바이트 | 녹화 프로세스가 SIGINT 를 못 받은 것. 워크플로의 "화면 녹화 종료" 스텝 로그 확인 |
| Actions 분 초과 | 저장소 Settings → Billing 확인. 캡처가 필요할 때만 푸시할 것 |
