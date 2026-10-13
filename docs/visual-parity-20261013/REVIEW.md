# Android / iOS 실제 화면 검수 — 2026-10-13

**판정: 전체 UI·모션 완전 일치 기준은 아직 미충족이다.**
기능 테스트 통과와 시각적 일치를 구분한다. 이번 대조에서 누락 로고, 알림 화면/저장 방식, 패스 폰트·배치, 정원 타이핑·대화창 차이를 발견하고 수정했다.

[14개 화면 대조와 낙하 연속 캡처 열기](index.html)

| 비교 | 확인 결과 | 남은 차이/검증 한계 |
| --- | --- | --- |
| [등록 완료](bloom-create-pair.png) · [수정 완료](bloom-update-pair.png) · [삭제 완료](bloom-delete-pair.png) | 동일 411.43 dp/pt, 제목·185만 원·잔여1965만 원. 누락 로고/꽃 외곽선/줄 높이/닫기/푸터 수정 후 주요 배치 확인 | 글리프·벡터의 미세 렌더링. 정지 본문 캡처여서 실기기 기울기 미검증 |
| [알림 기본](reminders-default-pair.png) · [권한/패스 없음](reminders-blocked-pair.png) | 동일 390 dp/pt, 날짜·4개 결제·2455만 원 또는 빈 목록. 헤더·수신 경로·선택 시점·자동 저장·경고 확인 | SF Symbols와 Material 아이콘, 일부 행 높이·줄바꿈·금액 합성 굵기 |
| [패스 처음](pass-opening-pair.png) | 제목 폰트·원본 로고·카드 비율·버튼 문구 수정. 혜택 진입 확인 | 카드 표면 조명·회전, 배경 광선, 안전 영역에 따른 위치 |
| [서류](pass-documents-pair.png) · [엑셀](pass-excel-pair.png) · [알림](pass-reminders-pair.png) · [청첩장](pass-invitation-pair.png) | 네 섹션 이동 및 상품 화면 연결 통과. 제목25/행32, 설명12/행19, 원본 시연340:271 비율과 중앙 배치 반영 | Android는 시연 완료 정지 프레임, iOS는 진행 중 캡처. 내부 배치·캡션·장식 차이도 남음. 전체 모션 동등성 미판정 |
| [정원 낙하](garden-flight-pair.png) | 실제 두 화면에서 하객이 분홍 헤더 위를 통과. Swift 렌더링에서 착지 후 헤더 복구와 대화창 글자 노출 검사 통과 | 캡처 시점·난수·기기 픽셀 폰트 밀도 상이. 이름표/말풍선 배치도 완전 일치하지 않음 |
| [혼자일 때 채팅](chat-solo-pair.png) | 초대 문구 수정·초대 동작 검증 | Android 단독 본문/iOS 앱 전체의 정렬 영역 차이. 버튼·행간 차이도 남음 |
| [둘러보기](explore-feed-pair.png) | 두 플랫폼의 실제 렌더링을 구조 참고용으로 제시 | 데이터가 달라 일치 판정에서 제외 |
| [플랜 추가](add-plan-pair.png) | 제목 드레스 투어·드레스·카드·금액0·날짜를 입력한 실제 폼 비교 | Android 위치 검증 오류/iOS 오류 전 상태. 제목 보조문구·카테고리 칩·버튼·시간 표시 차이가 남음. 빈 제목의 첫 단계 캡처는 비교에서 제외 |

## 실행 근거

- Android 기준: `b1e318b` (v35). API30 AOSP ATD, 1080×2400, 밀도420(2.625배). `debug.hwui.drawing_enabled=1` 확인 후 화면 테스트 24개 통과. API35 알림 테스트 2개도 별도 통과.
- iOS: Xcode26.2 / iOS26.2 / iPhone16e. 전체 UI **17개**, 네이티브 **8개** 통과. 이후 변경한 패스 화면·플랜 추가 캡처·알림 행간·완료 카드·실제 글자 렌더링 검사는 관련 테스트를 다시 통과했다.
- Core **389개 통과**. 원본 Kotlin 엔진에서 얻은 낙하 133프레임을 Swift와 대조. 위치·크기·압축/반동·포즈·착지 상태 허용 오차0.0002 world unit. 난수 먼지는 생성 수/소멸 경계만 비교.
- 대화창 글자 검사는 접근성 텍스트 존재 여부가 아닌 실제 밝은 글자 픽셀을 검사한다. 검사 비트맵을 8비트로 고정해 확장 색상 포맷 오판을 방지했다.
- 알림 저장 성공/실패 복구, 지난 알림 시점 건너뛰기, 낮12시 표기 검증 포함.
- `scripts/audit.py`, 패스 JavaScript 구문 검사, `git diff --check` 통과.

로컬 로그와 원본 xcresult: `/tmp/weddingplant-ios-port-20261013`.
전체 UI: `parity-verified-full.log`; Core: `parity-core-final2.log`;
추가 확인: `parity-final-visual.log`, `parity-add-filled.log`, `parity-native-resolution.log`.
각 이미지의 원본 경로와 판정은 [manifest.json](manifest.json)에 보존한다.

## 비교 방식과 남은 일

iOS Display P3 → sRGB 변환 후 390px 폭으로 나란히 표시한다. 알림은 Android API35 캡처의52dp 상단 인셋을 iOS 테스트에 동일하게 주입했다. 완료 카드도 원본 테스트와 같이 배경 모달을 제외한 본문과 동일 폭을 사용한다. 정원은 원본과 같은1080px 폭으로 캡처한다. GIF는 플랫폼별 캡처 간격/시점이 다르므로 동기화된 영상 비교가 아니다.

다음 시각 검수는 패스 시연을 같은 재생 시점으로 고정하고, 정원 말풍선/이름표, 아이콘·행간, 나머지 화면을 같은 데이터로 맞춘 뒤 대조해야 한다. 이 보고서는 해당 차이를 해결 완료로 표시하지 않는다.

실제 서버의 두 계정 로그인·초대·채팅·SSE·업로드·푸시, Apple 구매 검증은 별도 미완료 항목이다. UI 테스트는 DemoTransport 환경이며 실서비스 성공을 증명하지 않는다. 설정 의존성은 [전체 이식 기록](../ANDROID_PARITY_20261013.md#외부-설정과-결제-의존성)에 있다.

보고서 재생성: Pillow 환경에서 `scripts/visual-parity-report.py --android <Android shots> --ios <최신 xcresult export> <기존 export> --spec <비교 명세 JSON> --output docs/visual-parity-20261013`. 최신 폴더를 먼저 지정한다. 명세는 manifest의 `id/android/ios/fixture/note/review/motion` 필드를 사용할 수 있다.
