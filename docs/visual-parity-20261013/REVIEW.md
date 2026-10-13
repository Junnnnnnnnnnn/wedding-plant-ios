# Android / iOS 실제 화면 재검수 — 2026-10-13

요청받은 추가 검수를 수행하고 발견된 iOS 행간·아이콘·배치·모션 차이를 수정했다. [25개 실제 캡처와 낙하 연속 프레임](index.html)을 같은 조건으로 다시 대조했다. 이 기록은 검수한 화면과 시점에 대한 결과이며, 실서비스 전체 기능이나 모든 프레임의 픽셀 동일성을 의미하지 않는다.

| 비교 | 수정 및 확인 |
| --- | --- |
| [알림 기본](reminders-default-pair.png) · [권한 없음](reminders-blocked-pair.png) | 원본 Material 벡터, 1.5배 줄 높이·양끝 반 줄 여백, 어절 줄바꿈, 금액 합성 굵기, 스위치·경고·행 높이 |
| [플랜 추가](add-plan-pair.png) | 같은 입력·날짜·장소 오류·스크롤0. 제목 보조문구, 금액 안내, 칩·시간·버튼, 빈 장소 검색의 오류와 400ms 흔들림. 한글 조합 중 입력 보존 |
| [둘러보기](explore-feed-pair.png) | 같은 API 응답으로 통계·헤더·금액·별점·본문·작업 버튼·하단 탭 비교. 신고 버튼의 불필요한 높이 제거와 긴 제목 줄바꿈 |
| [채팅 초대](chat-solo-pair.png) · [초대 불가](chat-unavailable-pair.png) | 같은 독립 본문 영역, 카카오 글꼴·행간·아바타·링크 아이콘·정렬 |
| [등록](bloom-create-pair.png) · [수정](bloom-update-pair.png) · [삭제](bloom-delete-pair.png) | 같은 185만 원·잔여1965만 원. 본문 글꼴·줄 높이·로고·꽃·닫기·푸터 |
| [패스 시작](pass-opening-pair.png) · [최종](pass-final-pair.png) | 원본 카드 표면·서체·광택·배경 좌표와 문구 배치. iOS는 광고가 없어 원본의 조건부 ‘광고 없이’ 칩을 생략 |
| [서류](pass-documents-pair.png) · [엑셀](pass-excel-pair.png) · [알림](pass-reminders-pair.png) · [청첩장](pass-invitation-pair.png) | Android 340×271 시연을 Canvas로 이식. 원본 사진·벡터·좌표·폰트와 6600ms 완료 화면 비교. 네 시연 중간 시점도 별도 비교 |
| [오프닝1200](pass-opening-1200-pair.png) · [2450](pass-opening-2450-pair.png) · [4000](pass-opening-4000-pair.png) | 봉투·이음매·카드 회전/등장·후광·18개 광선·고리·입자의 원본 시간/이징 이식. 중복 원근 투영 제거. Android 테스트의 누적 프레임 반올림도 제거 |
| [빈 정원](garden-empty-pair.png) · [하객 말풍선](garden-bubble-pair.png) | 픽셀 글꼴의 18px 행간·14px 기준선, 이름표·외곽선·꼬리·진행 표시. 스크롤/터치 시 자동 닫힘 중지와 닫기 동작 검증 |
| [정원 낙하](garden-flight-pair.png) | 양쪽 실제 렌더러에서 헤더 위 통과와 착지 후 복구 검증. 원본 Kotlin 엔진의 133프레임 좌표·크기·반동·포즈는 Swift Core와 오차0.0002 world unit 이내 대조 |

## 최종 실행 결과

- 기준 Android `b1e318b` v35, 비교 테스트 보강 커밋 `9a6e1c2` (제품 코드 변경 없음). 일반 API35 에뮬레이터, 1170×2532, density480(390×844dp·3배). 이전 ATD 캡처는 최종 비교에서 제외했다.
- iOS: Xcode26.2 / iOS26.2 / iPhone16e. **전체 UI17개 + 네이티브14개, 실패0** (`final-review19.log`). PDF3양식·권한·알림 저장 실패 복구·동일 데이터 캡처·WK 실제 색상 픽셀 검사 포함.
- Core **391개, 실패0** (`core-second-review.log`). 이번 추가 검수의 말풍선 수동 유지와 알 수 없는 하객 수 분기 포함.
- Android 재실행: 패스/정원 글꼴10개, 낙하/빈 좌석/하객3개, 완료 카드4개, 둘러보기2개, 스크롤0 플랜 추가1개 통과. 최종 캡처 밀도 변경 후 정원 글꼴2개 재통과 (`android-garden20.log`).
- 말풍선 꼬리 좌표59를 통일한 추가 검사 통과 (`bubble20-verified.log`). 이후 패스 봉투 모서리·중간 배경 시계와 채팅 오류 상태의 비교 인셋을 바로잡고 시각 검사9개 재통과 (`visual22.log`). Android 중간 시연도 재통과 (`android21-midway.log`).
- 청첩장 타이핑 경계2200ms는 한 프레임 차이로 표시 글자가 달라질 수 있어2225ms로 고정했다. 원본과 iOS 모두50ms 단위 글자 갱신 규칙을 유지한다.
- 정적 감사, JavaScript 구문 검사, `git diff --check` 확인.

원본 로그·xcresult는 `/tmp/weddingplant-ios-port-20261013`. [manifest.json](manifest.json)에 각 캡처 출처·조건을 기록했다. 재현 명세 [spec.json](spec.json)과 `scripts/visual-parity-report.py`를 함께 보존한다.

## 비교 조건과 검증 범위

같은 데이터·390dp/pt·3배 배율로 앱 영역을 비교했다. 알림/추가/피드/채팅 상단 인셋48, 추가/피드 하단24. iOS Display P3는 sRGB로 변환했다. 완료 카드의 Android OS 바와 말풍선 바깥 정원/흰 배경은 비교 대상에서 제외한다. 플랫폼 글리프 안티앨리어싱·서브픽셀 반올림은 남을 수 있다.

패스는 동일 시각을 지정해 완료 및 중간 프레임을 비교한다. Compose와 WK의 프레임 양자화에 따른 수ms 차이는 가능하다. 낙하 GIF는 캡처 간격·시점·난수가 달라 재생 위상 일치를 주장하지 않는다. 좌표 궤적은 별도 수치 테스트로 검증하고 난수 먼지는 생성 수·소멸 경계만 대조한다.

실제 서버의 두 계정 인증·초대·채팅·SSE·업로드·푸시와 Apple 구매 연동은 미검증이다. 현재 구매는 StoreKit 가격 조회까지만 구현되어 있다. 필요한 설정과 남은 연동은 [이식 기록](../ANDROID_PARITY_20261013.md#외부-설정과-결제-의존성)에 명시했다. UI17개는 DemoTransport 환경이며 실서비스 성공의 증거가 아니다.
