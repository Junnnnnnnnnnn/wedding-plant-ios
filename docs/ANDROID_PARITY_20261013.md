# Android → iOS 이식 및 검증 기록

추가 시각 검수와 iOS 수정·재검증을 수행했다. 최신 결과는 Core391개·UI17개·네이티브14개 통과, 같은 조건의 화면25개 대조다. 외부 계정·푸시·Apple 구매 연동은 아래 별도 미완료 항목이다.

기준: Android `b1e318b` (앱 v35), iOS 시작점 `e9e4120`.
iOS main을 원격 최신으로 fast-forward한 뒤 작업했다. 2026-10-13 재확인 시 origin/main 추가 커밋 없음.

## 구현

- 5개 탭, 홈 예산 카드·이번 주 결제할 것, 일정 탭, 둘러보기 피드·자랑·청첩장과 통계 헤더.
- 후기 목록에서 내 플랜으로 복사·신고·차단. 제목·카테고리·금액·장소 사전 입력.
- 작은 화면 홈 스크롤에서 발견한 LazyVStack 배치 반복을 일반 스택으로 수정.
- 사용자 입력·금액 글꼴은 Android와 같은 Tmoney Regular 파일(ExtraBold 대체 방지).
- 이메일 가입·로그인·인증·비밀번호 재설정, Google 네이티브 로그인과 설정 항목.
- 401/403 세션 보존, 요청 당시 세션에만 갱신 토큰 반영.
- 일정 완료/결제 상태, 소수 금액의 조회·수정·합계·표시·내보내기 보존.
- 원본 카테고리 아틀라스, 검색·직접 추가·확인 선택기.
- 준비 패스 조회·소개 및 혜택 시연, 결제일 알림 설정.
- 서류 열람, 수정 화면에서 첨부·삭제, QuickLook, 전체 다운로드·취소·오류 처리.
- 일정 전체 페이지 조회와 PDF·엑셀 3가지 양식, 기간 선택, 실제 파일 공유.
- 무료 예시 데이터 17건, PDF 미리보기와 명시적 닫기 버튼.
- PDF 원본 좌표·폰트·색상·페이지 분할. 두 번 그릴 때 빈 파일이 되던 문제 수정.
- 엑셀 요약/상세 시트·날짜 값·수식 캐시·필터·막대·사용자 입력 문자열 셀.
- 신랑·신부 채팅 직행/혼자일 때 초대/오류 재시도, 관계 해제·이동 확인.
- 채팅 일정 선택·전송, 상세에서 공유, 활동 기록, 누락 메시지 재조회, Socket.IO ack.
- 채팅 신고, 피드·자랑 신고/차단 및 차단 목록.
- 전경 SSE, 방 구성 변경, 미읽음, 푸시 중복 억제, 백그라운드 정리.
- 온보딩 축하 효과·권한 안내, 등록·수정·삭제 완료 꽃 카드와 기울기 모션.
- 청첩장 API·저장 경쟁 처리·로컬 초안·사진 업로드·편집·공개·QR·링크.
- 원본 정원/인물/문/로고 이미지와 카카오·픽셀 폰트, 하단 탭 벡터.
- 정원 걷기·좌석·말풍선·낙하·착지 압축·먼지·반동·손 흔들기.
- 홈 정원은 원본 GardenPeek의 y=172부터 160 높이, 2:1 창으로 자르고 대화창을 제외.
- 미리보기 3색 팔레트, 0.7초 대기+2.4초 문 열림, 글자·반짝이.
- 청첩장 구성·분위기·표지·하객 패널, 가족·달력·모자이크 갤러리·장소·계좌·축하의 정원.

준비 패스 소개는 로컬 WKWebView를 사용하며, Android의 혜택 시연과 카드 오프닝을 원본 좌표·키프레임·이징을 따르는 Canvas 렌더러로 이식했다.
계정·구매·청첩장 편집은 SwiftUI 화면으로 연결된다. 소개 리소스의 외부 웹 의존성은 제거했다.

## 검증

Xcode 26.2 / iOS 26.2 / iPhone 17·iPhone 16e 시뮬레이터.

- Core **389개 통과** (`parity-core-final2.log`). 금액 소수 보존·완료 결제 상태·권한 선택·초대·인증·SSE·Socket.IO·청첩장 정규화·낙하 궤적·내보내기 페이지 무결성 포함.
- 네이티브 3개 통과 (`ui-final7-small.log`): 세 PDF 양식에 일정 80개를 넣어 PDFKit으로 제목·소수 금액·A4 폭·여러 페이지 확인. OWNER/SPOUSE/WRITE/READ 동작과 권한 조회 실패 시 쓰기·서류 접근 차단 검증.
- 엑셀 3개를 독립 Python ZIP/XML 판독기로 검사. CRC·전체 XML·수식 캐시·막대 범위 정상.
- iPhone 17 UI: 종합 16개 중 패스 상품 링크 1개 실패 후 네이티브 URL 연결 수정. 관련 4개(주간 결제 신규 포함) 재검증 통과 (`ui-final4.log`, `ui-final5.log`).
- iPhone 16e **최종 UI 종합 17개 전부 통과**, 네이티브 3개 전부 통과 (`ui-final7-small.log`).
- UI 범위: 5탭, 초대/관계 관리, 둘러보기, 후기 복사, 패스 소개→상품, PDF·엑셀 공유/예시 미리보기, 카테고리, 홈·주간 결제·알림, 등록/수정/삭제 꽃 카드, 온보딩, 이메일 입력/로그인, 청첩장 생성·저장·공개·낙하·미리보기.
- 작은 화면에서 재현한 홈 스크롤 정지는 프로세스 샘플의 반복 배치를 확인해 LazyVStack을 일반 스택으로 변경. 실패하던 시나리오가 최종 종합 검사에서 11.4초에 통과.
- 원본 프레임 캡처에서 하객이 정원 위 분홍 헤더를 통과해 내려오는 모습 확인. 엔진의 궤적·먼지·압축·반동·손 흔들기는 Core 검증. 전 프레임 픽셀 비교 자동 판정은 없음.
- `python3 scripts/audit.py`, `git diff --check` 통과.

UI는 `DemoTransport`를 사용하는 격리 테스트다. 실제 서버 로그인·결제·업로드·채팅 전송·푸시 성공을 증명하지 않는다.
기존 `ScreenshotTests`는 조건부 탐색과 캡처용이며 기능 통과 수에 포함하지 않았다.
로그/xcresult/스크린샷/파일: `/tmp/weddingplant-ios-port-20261013`.

재현:

```sh
xcodegen generate
swift test --package-path Core
python3 scripts/audit.py
xcodebuild -project WeddingPlant.xcodeproj -scheme WeddingPlant \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO \
  -only-testing:WeddingPlantTests \
  -only-testing:WeddingPlantUITests/AndroidParityUITests test
```

## 2026-10-13 추가 대조 및 수정

[25개 화면 대조 HTML](visual-parity-20261013/index.html) · [최종 검수 결과](visual-parity-20261013/REVIEW.md)

- 일반 Android API35와 iOS를390dp/pt·3배 배율로 통일했다. 이전 ATD 캡처는 폐기하고 같은 API 데이터·인셋·스크롤·오류 상태로 다시 촬영했다.
- Compose 줄 높이와 첫/마지막 반 줄 여백, 어절 줄바꿈, Tmoney 합성 굵기, 원본 Material 아이콘을 적용했다. 알림·플랜 추가·피드·채팅·완료 카드를 재대조했다.
- 패스의 네 혜택 시연, 봉투·카드 오프닝·배경·광선·광택을 원본 좌표·타임라인으로 이식하고 완료 및 중간 시점13개를 비교했다.
- 정원 이름표·말풍선·정원지기 대화창의 픽셀 폰트 기준선·행간·꼬리·테두리를 수정했다. 공개 여부·방명록·하객 수별 실제 정원 문구를 일치시켰다.
- AndroidMotionReferenceTests는 원본 Kotlin133프레임과 위치·크기·압축·반동·포즈·착지 상태를 비교한다(허용 오차0.0002 world unit). 실제 양쪽 렌더러에서도 헤더 위 낙하와 착지 후 복구를 검사했다.
- 최신 전체 재검증은 **UI17개 + 네이티브14개**, Core **391개** 통과. `final-review19.log`, `core-second-review.log`. 위 ‘검증’ 절의 이전 실행 기록을 대체하는 최신 결과다.

## 남은 검증과 차이

- [최종 화면 대조 보고서](visual-parity-20261013/index.html)에25개 비교를 기록했다. 이번 검수에서 확인한 행간·아이콘·배치·시연 차이는 수정 후 재대조했다. 플랫폼 글리프 안티앨리어싱·난수 입자·OS 영역 및 iOS 광고 혜택 생략은 구분한다. 모든 화면/모션 프레임의 픽셀 동일성 검사는 아니다.
- 엑셀은 데이터·수식·기본 색상/배치를 옮겼지만 원본의 모든 셀 스타일/인쇄 장식을 픽셀 단위로 일치시키지는 않았다.
- 서류 사진은 iOS JPEG 인코딩을 사용한다(Android WebP와 파일 크기는 다를 수 있음).
- 실제 두 계정으로 가입·초대·채팅·SSE·업로드·공개 링크를 왕복하는 연동 검사.
- 실기기 APNs/FCM, 기울기 센서, 접근성 글자 크기와 VoiceOver의 전 화면 검사.

## 외부 설정과 결제 의존성

현재 `Config/Local.xcconfig`, Firebase `GoogleService-Info.plist`가 없다.
Google iOS/server client ID, Kakao iOS 등록, Apple 로그인/서명/APNs 설정과 테스트 계정이 필요하다.
비밀값은 저장소·로그에 넣지 않는다.

확인한 API 저장소에는 Google 구매 검증만 있고 Apple 구매 검증 엔드포인트가 없다.
현재 iOS 패스 화면은 StoreKit 상품 가격 조회까지만 구현했고 구매를 실행하지 않는다.
Apple 서버 검증·권한 부여와 App Store 상품 등록/테스트 환경이 연결되어야 결제 기능을 완료할 수 있다.
이 상태를 출시 가능 또는 전 기능 완료로 표시하면 안 된다.

Android 전용 AdMob은 포함하지 않았다(원본 커밋의 적용 범위도 Android 전용).

## 원래 파일 보존

작업 전 미추적 `App/Resources/Info.plist`는 `/tmp/weddingplant-ios-port-20261013/original-Info.plist`에 백업했다.
`project.yml`이 생성 원본이며 생성 plist·Xcode 프로젝트·로컬 설정은 커밋에 넣지 않는다.
