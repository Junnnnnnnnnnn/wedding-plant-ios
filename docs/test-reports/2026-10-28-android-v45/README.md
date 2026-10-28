# Android v44 · v45 — Android ↔ iOS 1:1 (2026-10-28)

Android `main` `7622e73`(에뮬레이터 `WeddingPlant_API35`). 화면 폭을 맞추려고 Android 는 `wm density 443`(390dp)로도 찍었다.

| 쌍 | 장면 | 결과 |
| --- | --- | --- |
| [01](compare/01-feed-new-post-notice.png) | 새 후기 안내 `이름 없이 공개돼요. 로그인하지 않은 사람과 검색 결과에도 보일 수 있어요.`(69749f3) | 같음 |
| [02](compare/02-export-xlsx.png) | 내보내기 시트 — 머리 글 · 형식 설명 · 미리보기 아래 두 줄 · 아래 둘째 줄을 뺌(7622e73) | 같음. **iOS 기간 칩이 두 줄로 꺾이던 것**을 찾아 한 줄로 고침 |
| [03](compare/03-export-pdf-sample.png) | PDF + 예시 데이터 | 같음 |
| [04](compare/04-update-prompt.png) | 새 버전 알림 `업데이트 / 나중에`(373ec6f) | 같음(390 폭에서 본문 줄바꿈까지) |

- Android `CalendarExportShotTest` 는 앱 테마 없이 그려 시스템 글꼴로 찍힌다 — 02 · 03 은 같은 본문을 `WeddingPlantTheme` 안에서
  찍은 임시 캡처(커밋하지 않음)와 비교했다. 그렇게 보니 학교안심 굵게 13 의 `전체 기간 · 날짜 미정 포함` 이 Android 는 한 줄에 딱
  맞고 iOS 는 둘째 줄로 꺾였다 → `lineLimit(1)` + 10% 까지 줄임.
- 01 의 Android 는 지난번 임시 캡처(`ZzIosParityFeedShotTest`)를 다시 써서 찍고 지웠다. 예시 데이터 수(17 · 4개 일정)는 서로 다르다.
- 새 버전 알림: iOS 는 Play 대신 App Store 공개 조회(`itunes.apple.com/lookup`)로 판정. `AppUpdatePromptUITests` 가 켤 때 · 다시 들어올 때
  (열린 시트 위) · 나중에 · 바깥 누름 · 같은 버전이면 없음을 본다. 지금 앱은 스토어에 없어(심사 중) 실제 조회는 결과 0개 → 띄우지 않음.
