# 테스트 가이드

이 문서의 모든 명령과 출력은 이 PC(Windows 11 + Swift 6.3.3)에서 실제로 실행해 확인한 것이다.

---

## 0. 지금 테스트할 수 있는 것 / 없는 것

| 대상 | Windows에서 테스트 | 방법 |
| --- | --- | --- |
| 모델·JSON 디코딩 (`WPModels`) | 가능 | `swift test` |
| KST 날짜·JWT (`WPUtils`) | 가능 | `swift test` |
| API 호출 로직 (`WPNetworking`) | 가능 | `MockTransport` 주입 |
| 로그인 후 라우팅·예산 계산 (`WPDomain`) | 가능 | `swift test` |
| **SwiftUI 화면** | **불가** | macOS CI 시뮬레이터 (§5) |
| **실기기 동작** | **불가** | TestFlight (§5) |

현재 `App/` 타깃이 아직 없으므로 **지금 돌릴 수 있는 건 `Core/` 뿐**이다.
그래도 앱 로직의 상당 부분이 Core에 있어서 여기서 잡히는 버그가 많다.

---

## 1. 실행

가장 간단한 방법 — 래퍼 스크립트를 쓴다. 환경 준비를 알아서 한다.

```powershell
cd <저장소 폴더>   # 예: C:\dev\wedding-plant-ios

.\scripts\test.ps1                                  # 전체 (82개)
.\scripts\test.ps1 KstDateTests                     # 특정 스위트만
.\scripts\test.ps1 KstDateTests/test_days_until     # 특정 테스트 하나만
.\scripts\test.ps1 -List                            # 테스트 목록만 출력
.\scripts\test.ps1 -Build                           # 테스트 없이 빌드만
```

`swift` 명령을 직접 쓰고 싶으면 **새 창마다** 환경을 먼저 불러와야 한다.

```powershell
. .\scripts\swift-env.ps1     # 점(.) 하나 + 공백. 이게 없으면 안 된다
cd Core
swift test
swift test --filter KstDateTests
swift test list
```

`.\scripts\swift-env.ps1` 처럼 점 없이 실행하면 자식 프로세스에서만 환경이 설정되고
현재 창에는 반영되지 않는다. **반드시 `. .\scripts\...` (점-공백-경로) 형태로 실행할 것.**

---

## 2. 출력 읽는 법

### 성공

```
Test Case 'KstDateTests.test_today_KST자정_직후는_다음날이다' passed (0.0 seconds)
...
Test Suite 'All tests' passed at 2026-08-14 02:14:26.182
	 Executed 82 tests, with 0 failures (0 unexpected) in 0.506 (0.506) seconds

PASS (exit 0)
```

### 실패

파일 경로와 **줄 번호**, 그리고 기대값 대 실제값이 그대로 찍힌다.

```
C:\...\Core\Tests\WPUtilsTests\TempFailureDemo.swift:7: error: TempFailureDemo.test_일부러_실패시키기 :
  XCTAssertEqual failed: ("Optional("2026-08-14")") is not equal to ("Optional("2026-08-15")")
Test Case 'TempFailureDemo.test_일부러_실패시키기' failed (0.005 seconds)
	 Executed 1 test, with 1 failure (0 unexpected) in 0.005 (0.005) seconds

FAIL (exit 1)
```

VS Code 터미널에서는 저 파일 경로가 클릭 가능하다.

### 무시해도 되는 것

```
warning: unable to create symbolic link at ...\.build\debug (I/O error 512)
```

Windows 심볼릭 링크 권한 문제. 빌드·테스트는 정상이다. 없애려면 Windows 개발자 모드를 켠다.

맨 끝에 항상 붙는 아래 두 줄도 정상이다. Swift 6에 함께 들어 있는 새 테스트 프레임워크
(swift-testing)가 있는지 확인하는 것이고, 이 프로젝트는 XCTest만 쓰므로 0개가 맞다.

```
◊ Test run started.
√ Test run with 0 tests in 0 suites passed after 0.001 seconds.
```

---

## 3. 직접 해보기 — 테스트가 회귀를 잡는지 확인

가장 확실한 검증은 **일부러 깨뜨려 보는 것**이다.

1. `Core/Sources/WPUtils/KST.swift` 를 연다.
2. 다음 줄을 찾아 `9` 를 `8` 로 바꾼다.

   ```swift
   public static let secondsFromGMT = 9 * 60 * 60
   ```

3. 실행한다.

   ```powershell
   .\scripts\test.ps1 KstDateTests
   ```

   `test_today_KST자정_직후는_다음날이다`, `test_today_연말_경계` 등이 실패해야 한다.
   실패 메시지에 `"2026-08-15"` 대신 `"2026-08-14"` 가 나온다.

4. `9` 로 되돌리고 다시 실행 → 다시 통과.

이게 되면 테스트 환경이 제대로 동작하는 것이다.

---

## 4. 테스트 추가하기

파일을 `Core/Tests/<타깃>Tests/` 아래에 만들면 **자동으로 발견된다.**
별도 등록(`XCTestManifests` 같은 것)은 필요 없다.

```swift
// Core/Tests/WPDomainTests/MyNewTests.swift
import XCTest
import WPModels
@testable import WPDomain

final class MyNewTests: XCTestCase {
    func test_설명을_한글로_써도_된다() {
        XCTAssertTrue(PlanCompletion.isComplete(name: "지수", weddingDate: "2026-10-10", budget: 100))
    }
}
```

규칙 세 가지만 지키면 된다.

- 클래스는 `XCTestCase` 상속, `final`
- 메서드 이름은 `test` 로 시작
- `import` 하는 모듈은 `Package.swift` 의 해당 testTarget `dependencies` 에 들어 있어야 한다

### 네트워크 호출을 테스트할 때

실제 서버를 부르지 않는다. `MockTransport` 로 응답을 지정한다.

```swift
let transport = MockTransport()
await transport.stub(path: "/plan/user", json: #"{"result":true,"data":{"name":"지수"}}"#)

let store = InMemoryTokenStore(token: "eyJ...")   // 만료되지 않은 JWT
let client = APIClient(
    baseURL: URL(string: "https://api.example.com")!,
    transport: transport,
    tokenStore: store
)

let user = try await client.send(Endpoint.user(), decoding: PlanUser.self)
XCTAssertEqual(user.name, "지수")

// 실제로 나간 요청도 검증할 수 있다
let sent = await transport.lastRequest()
XCTAssertEqual(sent?.headers["Authorization"], "Bearer eyJ...")
```

`Tests/WPNetworkingTests/APIClientTests.swift` 에 401 처리, 만료 토큰 차단,
쿼리스트링, 경로 인코딩 예제가 다 들어 있으니 복사해서 쓰면 된다.

### 시각에 의존하는 테스트

`Date()` 를 함수 안에서 직접 부르면 자정 근처에서만 깨지는 테스트가 된다.
Core의 시각 관련 API는 전부 `now:` 파라미터를 받으므로 항상 주입한다.

```swift
let now = utc(2026, 8, 14, 15, 0)          // UTC 15:00 = KST 다음날 00:00
XCTAssertEqual(KstDate.today(now: now).dateString, "2026-08-15")
```

---

## 5. 앱(화면)을 테스트하려면

Windows에서는 SwiftUI를 컴파일조차 못 하므로, 아래 순서를 거쳐야 실제 화면을 볼 수 있다.

1. **Apple Developer Program 가입** ($99/년, 승인에 며칠)
2. `project.yml` + 빈 SwiftUI 앱 작성
3. GitHub Actions macOS 러너에서 빌드 성공시키기
4. **시뮬레이터 스크린샷을 CI 아티팩트로 받기** — Windows에서 화면을 눈으로 확인하는 유일한 방법
   ```
   xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 16'
   → xcresulttool 로 스크린샷 추출 → upload-artifact → zip 다운로드
   ```
5. **TestFlight 내부 테스트** — 실기기(iPhone)에 설치. 심사 없이 즉시 가능

자세한 절차와 워크플로 전문은 [`IOS_DEV_ON_WINDOWS.md`](IOS_DEV_ON_WINDOWS.md) §5, §6 참고.

CI에서는 Core 테스트를 **Linux 컨테이너**에서 먼저 돌린다(무료·빠름). macOS 러너는
UI 빌드에만 쓴다. 이 분리 때문에 CI 비용이 크게 줄어든다.

---

## 6. 자주 만나는 오류

| 메시지 | 원인 / 해결 |
| --- | --- |
| `toolchain is invalid: could not find CLI tool 'link'` | MSVC 환경 미로드. `. .\scripts\swift-env.ps1` 실행 |
| `unable to load standard library for target 'x86_64-unknown-windows-msvc'` | `SDKROOT` 없음. 같은 스크립트로 해결. 스크립트가 환경변수 전체를 다시 읽는다 |
| `swift : ...` 로 시작하는 빨간 에러인데 테스트는 다 통과 | PowerShell이 네이티브 stderr를 에러로 감싼 것. `2>&1` / `2>$null` 을 빼고 `$LASTEXITCODE` 로 판단 |
| `no such module 'WPModels'` | `Package.swift` 의 해당 testTarget `dependencies` 에 모듈 추가 |
| 새로 만든 테스트가 실행되지 않음 | 메서드 이름이 `test` 로 시작하는지, 클래스가 `XCTestCase` 를 상속하는지 확인 |
| 빌드가 이상하게 꼬임 | `Remove-Item -Recurse -Force Core\.build` 후 재시도 |
