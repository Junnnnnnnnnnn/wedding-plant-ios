# WeddingPlantCore

UI가 아닌 모든 코드를 담는 SwiftPM 패키지. **Windows에서 그대로 빌드·테스트된다.**

```powershell
cd Core
swift build
swift test
```

## 타깃 구성

| 타깃 | 내용 | 의존 |
| --- | --- | --- |
| `WPModels` | 백엔드 응답/요청 DTO, `APIEnvelope` | — |
| `WPUtils` | KST 날짜(`KstDate`), JWT 디코더 | — |
| `WPNetworking` | `HTTPTransport` 프로토콜, `APIClient`, `Endpoint` 카탈로그, `MockTransport` | WPModels, WPUtils |
| `WPDomain` | 로그인 후 라우팅, 플랜 완성도 판정, 게스트 마이그레이션, 예산 요약 | WPModels, WPUtils, WPNetworking |

## 설계 규칙

### 1. UIKit / SwiftUI / Security 를 절대 import 하지 않는다

이 패키지가 Windows에서 컴파일되는 것이 전체 개발 전략의 전제다.
플랫폼 의존 코드는 `App/Sources/Platform/` 에 두고, Core는 프로토콜만 안다.

| Core의 프로토콜 | App의 구현 |
| --- | --- |
| `HTTPTransport` | `URLSessionTransport` |
| `TokenStoring` | `KeychainTokenStore` |

### 2. `URLSession` 을 Core에서 쓰지 않는다

Windows의 `swift-corelibs-foundation` 은 `URLSession` 을 별도 모듈(`FoundationNetworking`)로 분리해 두었고
동작도 불완전하다. 그래서 전송 계층을 `HTTPTransport` 로 추상화하고, 테스트는 `MockTransport` 를 주입한다.

### 3. 시각은 항상 주입 가능하게 만든다

`KstDate.today(now:)`, `GuestMigration.settingRequest(now:)` 처럼 `now` 를 파라미터로 받는다.
`Date()` 를 함수 안에서 직접 부르면 자정 경계 테스트가 불가능해진다.

### 4. 백엔드 계약을 그대로 존중한다

- 응답은 모두 `{ result: Bool, data: ... }` → `APIEnvelope<T>`
- `Plan.onwerName` 오타는 백엔드 계약이므로 필드명을 유지한다 (읽기용 `ownerName` 별칭 제공)
- 금액 단위는 **만원**
- 알 수 없는 enum 값(권한·상태)이 와도 디코딩이 깨지지 않도록 `RawRepresentable` 구조체를 쓴다

## 웹 대비 의도적으로 달라진 점

| 항목 | 웹 | iOS Core | 이유 |
| --- | --- | --- | --- |
| 토큰 저장 | 브라우저 스토리지 | `TokenStoring` 한 곳(Keychain) | 저장 위치 단일화 |
| 401 처리 | - | `APIError.unauthorized` + 토큰 자동 폐기 | 만료 시 사용자에게 알릴 수 있게 |
| 만료 토큰 | 그대로 요청 전송 | `exp` 확인 후 전송 자체를 차단 | 불필요한 왕복 제거 |
| 잘못된 날짜 | `2026-02-30` → `2026-03-02` 로 굴러감 | `nil` 반환 | 조용한 데이터 변형 방지 |
| ISO 날짜 문자열 | `parseLocalDate` 가 `null` | 앞 10자를 읽어 파싱 | `createDate` 같은 필드 대응 |
| 로그인 후 분기 | 250줄짜리 effect 안에 뒤섞임 | `PostLoginRouter` 순수 함수 | 전 분기 유닛테스트 가능 |

## 다음에 붙일 것

- `App/Sources/Platform/URLSessionTransport.swift`
- `App/Sources/Platform/KeychainTokenStore.swift`
- `App/Sources/Platform/SSEClient.swift` (포그라운드 전용 — 백그라운드 알림은 APNs 필요)
- `project.yml` (XcodeGen) + GitHub Actions 워크플로

자세한 배경은 `../docs/IOS_DEV_ON_WINDOWS.md` 참고.
