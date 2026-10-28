# 청첩장 v42 · v43 — Android ↔ iOS 1:1 (2026-10-28)

Android `main` `2c2fb4c`(에뮬레이터 `WeddingPlant_API35`, `InvitationEditorShotTest` 12개 · `HomeInvitationShotTest` 8개 통과)와
iOS 시뮬레이터(데모 모드, `InvitationEditorEntryUITests` · `InvitationPhotoAndWishesUITests`)를 같은 장면으로 찍었다.
예시 데이터는 다르다 — Android 는 목 서버(정우진 · 한채원, 사진 3장), iOS 는 데모(민준 · 지수 / 현진 · 미주, 사진 없음에서 시작).

| 쌍 | 장면 | 결과 |
| --- | --- | --- |
| [01](compare/01-new-layout.png) | 새 청첩장 → 구성 시트부터 | 같음 |
| [02](compare/02-existing-preview-first.png) | 기존 청첩장 `고치기` → 미리보기부터 · 아래 `구성 · 분위기 · 하객 화면` | 같음 |
| [03](compare/03-layout-from-button.png) | `구성` 단추로 시트 | 같음 |
| [04](compare/04-cover-photo-changed.png) | 표지 사진 바꿈(iOS 는 사진 앱에서 실제로 고름 — 90° EXIF 사진이 세로로 섬) | 같음 |
| [05](compare/05-saved.png) | 저장 뒤 | **처음엔 달랐음** — iOS 가 저장 응답으로 초안을 갈아 끼워 주소 없는 새 표지가 빈 정원으로 바뀜. `InvitationRules.mergePhotos`(Android 와 같음)로 고친 뒤 같음 |
| [06](compare/06-home-new-wishes.png) | 홈 `청첩장 공개 중 · 새 축하 2` · 최근 글 한 줄 | 같음(iOS 는 하객이 걸어 들어온 뒤 프레임) |

- iOS 가 시뮬레이터에 쓴 파일: `RIFF … Web/P image, VP8, 800x1600`(원본 3000×1500 + EXIF 6). 데모 서버는 `image/webp` 가 아니면 사진 자리를 거절한다.
- Android 첫 실행의 01 · 04 · 05 는 막 켠 에뮬레이터의 "System UI isn't responding" 창에 가려 다시 찍었다(앱 문제 아님).
