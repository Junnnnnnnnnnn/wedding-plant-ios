"""Screen/action inventory. Missing captures stay visible; they never count as pairs.

2026-10-14 저녁: iOS 미커밋 작업본(814defc 이후)을 final-unit · final-ui 로 다시 찍고 매핑·판정을 갱신했다.
iOS 캡처 이름은 그 두 번들에 실제로 있는 것만 쓴다(옛 실행의 캡처가 끼어들지 않게).
"""
CASES=[]
def add(group,title,a=None,i=None,action='조회',note='',same=False,issue=False):
    CASES.append(dict(id=f'case-{len(CASES)+1:03}',group=group,title=title,android=a,ios=i,action=action,note=note,same=same,issue=issue))

SECURE='보안 입력 칸이 비어 보이는 것은 시뮬레이터 캡처가 가린 입력값을 빼고 찍기 때문이다(눈 아이콘으로 보이게 하면 글자가 찍힌다 — email-compact-signup-shown 에서 확인).'
SHEET='iOS 26 시트는 좌우가 떠 있는 둥근 모양이다(유지 결정).'
NOKEY='이 iOS 시뮬레이터 캡처에는 키보드가 찍히지 않았다(키보드 자리가 빈 여백으로 보인다).'
LEADING=('캡처상 iOS 가 약 12pt 높지만(Android 약 52~53pt, iOS 약 64~65pt) Android 캡처 쪽 문제다 — 이 Android 샷 테스트는 '
         'setContent 에 앱 테마(WeddingPlantTheme → MaterialTheme(typography = WpTypography))를 씌우지 않아 글자가 글꼴 기본 줄 높이로 그려졌다. '
         '실제 앱의 Text 는 WpTypography 의 lineHeight 1.5em + M3 기본 LineHeightStyle(Center, Trim.None)이라 줄마다 1.5배를 차지하고, '
         'iOS wpTypography(1.5배·위아래 반씩)와 같다. Android 소스 값(글자 크기·굵기·간격 2·안쪽 여백 12/14·16)과 iOS 값이 모두 같아 iOS 는 고치지 않았다 '
         '(소스로 계산한 앱 높이: 12+21+2+18+12 = 65pt).')

# 로그인
add('로그인','로그인 진입','review-native-landing-top','parity-landing',note='실제 앱 첫 화면 캡처. 차이는 iOS 전용 Apple 로그인 버튼 하나이고(유지), 그 버튼만큼 소셜 버튼 묶음이 위로 올라간다. 맨 아래 「개발용 토큰으로 로그인」은 DEBUG 빌드에서만 보인다(LandingView.swift #if DEBUG).')
add('로그인','이메일 입력 · 키보드','port-email-keyboard','email-compact-initial',action='등록',note='Android 는 이메일을 적은 상태, iOS 는 열자마자 빈 칸. 양쪽 모두 키보드는 캡처에 없다. '+SHEET)
add('로그인','기존 계정 비밀번호','port-password-error','parity-email-password',note='이제 양쪽 모두 오류 상태(「이메일 또는 비밀번호가 맞지 않아요.」). '+SECURE+' '+SHEET)
add('로그인','회원가입 · 인증번호와 비밀번호',None,'email-compact-signup',action='등록',note='새 가입자의 비밀번호 단계. '+SECURE+' Android 대응 캡처 없음. '+SHEET)
add('로그인','비밀번호 재설정','port-reset-keyboard','email-compact-reset',action='수정',note='해결: 새 비밀번호 칸에 강력한 암호 제안을 꺼서 자동 강력한 암호 덮개가 더 이상 입력 칸을 가리지 않는다(재실행 통과). Android 는 코드 빈 칸·키보드 표시, iOS 는 코드 123456 입력 후·키보드 내림 상태. '+SECURE+' '+SHEET)
add('로그인','카카오 실제 계정 인증',action='외부 연동',note='이번 보고서는 계정 인증을 다시 실행하지 않았다. 사용자 확인: 카카오 연결 완료.')
add('로그인','Google 실제 계정 인증',action='외부 연동',note='외부 OAuth 콘솔·실계정 로그인을 이번 비교에서 재검증하지 않았다.')

# 처음 설정 — iOS 는 OnboardingParityUITests(실제 다음 버튼으로 이동), Android 는 단계 상태를 지정해 캡처
add('처음 설정','축하 진입','review-onboarding-celebration','onb-celebration',action='등록',note='종이 가루 위치는 무작위라 프레임마다 다르다.')
add('처음 설정','예식 날짜','review-onboarding-date','onb-date',action='등록')
add('처음 설정','예산 입력','review-onboarding-budget','onb-budget',action='등록',note='고침: 게스트 저장소의 예산(Double)을 정수로 넣어 「5000.0」 대신 「5000」. 남은 값은 이전 실행이 남긴 게스트 예산이라 Android 기본값 1000 과 숫자만 다르다(테스트 데이터).')
add('처음 설정','이름 입력','review-onboarding-name','onb-name',action='등록',note='iOS 는 이전 실행의 게스트 저장 이름 「지수」가 미리 채워져 있어 다음 버튼이 켜진 상태, Android 는 빈 칸·버튼 꺼짐.')
add('처음 설정','환영','review-onboarding-welcome','onb-welcome',action='등록',note='iOS 「지수지수 님 환영합니다」는 미리 채워진 「지수」 뒤에 테스트가 「지수」를 한 번 더 적어서 생긴 값(테스트 데이터). Android 캡처는 이름 없이 「님 환영합니다」.')
add('처음 설정','약관 동의','review-onboarding-terms','onb-terms',action='등록')
add('처음 설정','권한 안내','permissions-step','onb-permissions',action='등록',note='Android 는 PermissionsStep 단독 캡처(상단 단계 막대 없음). 알림 줄 배지·버튼 문구가 다른 것은 시뮬레이터 알림 권한이 이미 허용(「켜져 있어요」·「다음」)이고 Android 는 미허용(「허용이 필요해요」·「알림 허용하고 계속하기」)이라서다.')
add('처음 설정','신랑·신부 초대','review-onboarding-invite','onb-invite',action='등록',note='Android 캡처는 단계 교차 페이드 중이라 권한 화면 내용이 6/6 막대와 함께 찍혔다. 같은 상태의 Android 초대 화면 캡처는 아직 없다.')
add('처음 설정','이름 입력 · 키보드',None,'onb-name-filled',action='등록',note='이름을 적고 키보드를 내린 뒤 찍었다(이 시뮬레이터 캡처에는 키보드가 찍히지 않아 테스트가 먼저 내린다). 값이 「지수지수」인 이유는 「환영」 항목 참고.')
add('처음 설정','약관 전체 동의 후',None,'onb-terms-agreed',action='등록')

# 홈
for pos,title in [('top','홈 상단'),('middle','이번 달 할 일'),('bottom','계획·완료 및 자랑하기')]:
    add('홈',title,'review-native-home-'+pos,'review-native-home-'+pos,note='양쪽 같은 방식의 화면 단독 렌더(탭바 없음). 테스트 이름·날짜·예산·목록 개수 차이가 있다. 금액 자체는 일치 판정 대상이 아니다. 실제 앱(탭바·상태바 포함) iOS 캡처는 parity-home-'+pos+' 에 있다 — 상태바 아이콘은 분홍 면 위 흰색, 흰 띠 위 어두운 색.')
add('홈','미구매 · 청첩장 안내 줄','home-invite-row','unpaid-home-invitation-row',note='패스·청첩장이 없으면 예산 카드 안의 「모바일 청첩장 · 구경하기」 줄만 내고 정원 카드는 숨긴다. 양쪽 일치.')
add('홈','미구매 · 기존 청첩장이 있으면 정원 카드','home-invite-draft','unpaid-existing-invitation-home',note='이제 iOS 도 Android 처럼 청첩장이 있으면(패스가 끝나도) 정원 카드 「청첩장이 아직 비공개예요 · 공개하기」를 낸다. Android fixture 는 패스 배지가 켜져 있고 iOS 는 미구매라 머리 면 배지만 다르다.')
add('홈','패스 보유 · 개인 정원','home-invite-empty','paid-home-garden',note='「하객 자리가 비어 있어요 · 만들기」 정원 카드. 이름·날짜 데이터 차이.')
add('홈','광고 삽입 위치','home-ad-anchor','ads-home',note='동일 광고 소재 비교가 아니라 광고 영역의 위치·노출 조건 비교.')
add('홈','준비할 일정이 없는 상태','home-empty-rest','parity-home-empty',note='새싹 그림·「첫 플랜을 심어 볼까요?」·「플랜 추가하기」. iOS 는 실제 앱 캡처라 자랑하기 도크와 탭바가 함께 보인다(Android 캡처 fixture 에는 자랑하기 없음).')
add('홈','예산 초과','home-budget-over','parity-home-over',note='「예산 초과 · 500만 원」 빨강. 데이터 차이 있음.')

# 일정
add('일정','월별 달력','port-calendar','cal-month',note='iOS 는 CalendarParityUITests 실제 앱 캡처(탭바 포함). 목록 데이터(일정 수·합계)가 다르다.')
add('일정','다음 달 이동',None,'cal-next')
add('일정','날짜 상세·추가',None,'cal-month-daylist')
add('일정','날짜를 지정한 등록',None,'cal-add-date',action='등록',note='제목을 적기 전에는 아래 칸이 숨는 단계형 폼이다(Android 도 RevealSection 으로 같음). Android 대응 캡처 없음.')
add('일정','달력 광고',None,'ads-calendar',note='테스트 견본이라 소재 없이 「광고」 자리만 찍혔다(실제 테스트 배너는 google-test-banner).')

# 등록
add('등록','빈 등록 폼',None,'review-create-start',action='등록',note='해결: Android 처럼 플랜 추가·수정 화면에도 하단 탭바가 남고 가운데 + 가 켜진다(다른 탭은 꺼짐, Android TabType.fromRoute(ADD_PLAN)=ADD). 탭 셸(MainTabShell)이 내용 자리에 덮어 그리며, 가운데 + · 홈 「추가」 · 달력 「+ 플랜 추가」 · 일정 상세 「수정하기」 · 피드 「담기」(후기 상세 포함) 모두 같은 길이고, 뒤로·저장(꽃 연출 뒤) 모두 누른 화면으로 돌아온다. 다른 탭을 누르면 플랜 추가는 빠진다. 화면에 소프트웨어 키보드가 뜨면 탭바를 내린다(Android showTabBar = onTabScreen && !imeVisible — 「저장 직전」 캡처에서 확인). 남은 것: 달력·채팅·결제 알림에서 전체 화면 창으로 연 일정 상세는 iOS 에서 그 화면부터 탭바가 없어(별도 차이) 거기서 연 수정은 예전처럼 전체 화면이다. Android 쪽 캡처는 화면 단독 렌더라 탭바 비교 이미지는 없다.')
add('등록','제목 입력 · 키보드','addplan-keyboard-up','review-add-title-keyboard',action='등록',note=NOKEY+' Android 는 키보드가 찍혔다.')
add('등록','카테고리 선택','port-picker-default','picker-default',action='등록',note='Android 는 선택기 단독 렌더, iOS 는 플랜 추가 위에 뜬 시트. 서버 카테고리 수가 달라 개수가 다르다(43 / 47). '+SHEET)
add('등록','카테고리 검색','port-picker-search','picker-search',action='등록',note=SHEET)
add('등록','직접 카테고리 만들기','port-picker-add','picker-add',action='등록',note=SHEET)
add('등록','결제유형·금액·날짜 폼','port-addplan-form','matched-addplan-form',action='등록',same=True,note='같은 fixture. 일자는 캡처한 날이라 하루 차이가 날 수 있다.')
add('등록','저장 직전',None,'review-create-ready',action='등록',note='이 캡처에는 iOS 키보드가 찍혔다. 키보드가 떠 있어 하단 탭바가 내려가 있다(Android showTabBar = onTabScreen && !imeVisible).')
add('등록','등록 완료 연출','bloom-create-amount','matched-bloom-create',action='등록',same=True)

# 수정
add('수정','일정 상세 상단',None,'detail-top-planned',note='지도는 Android 와 같은 카카오맵(KakaoMapsSDK) — 장소 카드 위 200. 달력·채팅에서 열어도 탭바가 남는다(Android SCHEDULE_DETAIL). Android 대응 캡처 없음.')
add('수정','상세 하단 · 공유·수정·삭제','detail-actions-planned','detail-actions-planned',note='보내기·공유 카드 + 삭제·수정하기. iOS 는 실제 앱이라 탭바가 아래에 있고, Android 도 SCHEDULE_DETAIL 에서 탭바를 둔다(캡처는 화면 단독).')
add('수정','완료한 일정 · 피드 공유','detail-actions-ready','detail-actions-ready',note='「예정으로 되돌리기」·「피드에 공유하기」 켜짐. 양쪽 일치.')
add('수정','수정 폼 상단','docs-edit-paid','matched-addplan-edit-top',action='수정')
add('수정','수정 폼 하단','docs-edit','matched-addplan-edit-docs',action='수정',note='서류 칸이 붙는 칸(+ · PDF)으로 나온다. 양쪽 일치.')
add('수정','수정 저장 직전',None,'review-edit-ready',action='수정')
add('수정','수정 완료 연출','bloom-update-amount','matched-bloom-update',action='수정',same=True)

# 삭제
add('삭제','일정 삭제 확인','detail-actions-delete','review-delete-confirm',action='삭제')
add('삭제','삭제 완료 연출','bloom-delete-amount','matched-bloom-delete',action='삭제',same=True)
add('삭제','금액 없는 일정 삭제','bloom-delete-none','matched-bloom-delete-none',action='삭제',same=True)

# 예산
for pos,title in [('top','예산 요약·도넛'),('middle','카테고리 지출'),('bottom','예정·사용 내역')]:
    add('예산',title,'review-native-budget-'+pos,'review-native-budget-'+pos,note='차트 수치는 공유한 fixture. 스크롤 위치가 플랫폼별 콘텐츠 높이에 따라 조금 다르다. 실제 앱 iOS 캡처는 parity-budget-'+pos+'.')
add('예산','예산 광고',None,'ads-budget')
add('예산','필터·예정/사용 전환',None,'parity-budget-filtered',note='카테고리 필터(웨딩홀) + 사용 탭. Android 대응 캡처 없음(사용 탭만은 parity-budget-used-tab).')

# 피드
add('피드','피드 첫 화면','explore-feed','matched-explore-feed',same=True)
add('피드','견적 후기 목록','review-native-feed-middle','review-native-feed-middle',note='스크롤 위치·데이터 차이.')
add('피드','후기 상세',None,'review-native-feed-detail-top',note='지도는 Android 와 같은 카카오맵(KakaoMapsSDK, 168 · 줌 15).')
add('피드','후기 상세 하단',None,'review-native-feed-detail-bottom')
add('피드','후기 등록 · 일정 선택',None,'matched-feed-post-pick',action='등록',note=SHEET)
add('피드','후기 등록 · 선택 후','detail-actions-sheet','matched-feed-post-selected',action='등록',note='일정 선택·만족도·한 줄 후기·금액 공개. 양쪽 일치. '+SHEET)
add('피드','후기 등록 · 게시 직전',None,'review-action-feed-post-ready',action='등록',note='외부 피드에는 게시하지 않았다. 화면 캡처와 실제 게시 검증은 별개다.')
add('피드','피드에서 내 플랜으로 가져오기',None,None,action='등록',note='AndroidParityUITests/testFeedCopyPrefillsPlan 기능 검증 결과 참고. 전후 이미지의 같은 데이터 대조는 미완료.')
add('피드','피드 광고',None,'ads-feed')

# 자랑하기
add('자랑하기','자랑 목록','explore-brag','matched-explore-brag')
add('자랑하기','자랑 상세','brag-detail','matched-brag-detail',note='Android 는 화면 단독, iOS 는 시트. 좋아요 버튼·도넛 범례 구성 일치. 범례 줄 간격이 iOS 가 조금 넓다.')
add('자랑하기','자랑 상세 하단',None,'review-native-brag-detail-bottom')
add('자랑하기','공개 토글 안내','toggle-normal','matched-toggle-normal',action='수정',note='줄 높이: '+LEADING+' 문구·스위치 위치는 같다.')
add('자랑하기','공개 제한 안내','toggle-locked','matched-toggle-locked',note='「신랑·신부를 등록하면 올릴 수 있어요」 잠금. 카드 높이 차이는 「공개 토글 안내」와 같은 원인.')
add('자랑하기','자랑 광고',None,'ads-brag')

# 채팅
add('채팅','대화 목록·메시지','port-chat-ready','matched-chat-ready',note='같은 대화 fixture. 결혼식까지 남은 날짜만 캡처한 날 차이. 실제 앱 캡처는 parity-chat-list.')
add('채팅','혼자 준비하는 경우','port-chat-solo','matched-chat-solo',same=True)
add('채팅','대화 불러오기 실패','port-chat-unavailable','matched-chat-unavailable',same=True)
add('채팅','플랜 선택해서 보내기','pick-list','matched-pick-list',note='플랜 줄 높이: '+LEADING.replace('12+21+2+18+12 = 65pt','12+21.75+2+18+12 ≈ 66pt — 제목 14.5')+' 제목·「스드메 · 11월 20일 · 300만원」 문구는 같다.')
add('채팅','플랜 선택 · 빈 목록','pick-empty','matched-pick-empty')
add('채팅','플랜 선택 · 오류','pick-error','matched-pick-error',note='줄 높이 차이는 「플랜 선택해서 보내기」와 같은 원인(Android 샷 테스트가 앱 테마 없이 그림 — iOS 는 소스 값과 같음).')
add('채팅','플랜 보내는 중','pick-sending','matched-pick-sending',action='등록',note='줄 높이 차이는 「플랜 선택해서 보내기」와 같은 원인(Android 샷 테스트가 앱 테마 없이 그림 — iOS 는 소스 값과 같음).')
add('채팅','플랜 보냄','pick-done','matched-pick-done',action='등록',note='고른 줄 체크. 줄 높이 차이는 「플랜 선택해서 보내기」와 같은 원인(Android 샷 테스트가 앱 테마 없이 그림 — iOS 는 소스 값과 같음).')
add('채팅','일정 상세에서 채팅으로 보내기','port-share-sheet','matched-share-sheet',note='보내기 · 보냄 · 혼자 세 상태를 세로로 이은 캡처. 양쪽 같은 구성.')

# 커플 관리
add('커플 관리','배우자 자리 경고(참여 전)','release-spouse-seat-named','matched-spouse-seat-named',note='「지금부터 초대한 사람의 플랜을 같이 쓰게 돼요」 경고창. 양쪽 일치(창의 세로 위치는 상태바 유무로 다름).')
add('커플 관리','신랑·신부 연결 해제 확인','release-couple-owner-confirm','matched-couple-owner-confirm',action='삭제')
add('커플 관리','배우자가 플랜 나가기','release-couple-spouse-leave','matched-couple-spouse-leave',action='삭제')
add('커플 관리','다른 플랜 초대 수락 제한','release-join-refused','matched-join-refused')
add('커플 관리','대화방 구성원 아님','release-chat-not-member','matched-chat-not-member')

# 프로필
for pos,title in [('top','프로필 기본 정보'),('middle','예산·저장'),('bottom','계정·문의·정책')]:
    add('프로필',title,'review-native-profile-'+pos,'review-native-profile-'+pos,note='Android 「예산·저장」 캡처는 예산 칸에 초점이 가 숫자 키보드가 찍혔다.' if pos=='middle' else '')
add('프로필','프로필 수정 · 키보드',None,'review-action-profile-edit-keyboard',action='수정',note=NOKEY)
add('프로필','프로필 저장 결과',None,'review-action-profile-saved',action='수정')
add('프로필','로그아웃 확인',None,'review-action-logout-confirm',action='삭제')
add('프로필','로그아웃 후',None,'review-action-logout-done',action='삭제')
add('프로필','회원 탈퇴 확인',None,'review-action-withdraw-confirm',action='삭제',note='운영 계정은 탈퇴시키지 않았다. 확인창까지 비교.')
add('프로필','차단 사용자 목록',None,'review-native-blocks-top')

# 신고·차단 — 시트 본문(ModerationSheetBody)만 양쪽 같은 방식으로 렌더
add('신고·차단','신고·차단 메뉴','moderation-menu','matched-moderation-menu')
add('신고·차단','신고 사유','moderation-reason','matched-moderation-reason',action='등록',note='본문 일치. iOS 위 여백이 몇 pt 크다.')
add('신고·차단','기타 사유 입력','moderation-reason-other','matched-moderation-reason-other',action='등록')
add('신고·차단','차단 확인','moderation-block','matched-moderation-block',action='등록')
add('신고·차단','신고·차단 처리 완료','moderation-done','matched-moderation-done',action='등록')

# 서류
add('서류','서류 보관함','documents-list-preview','vault-library',note='이제 iOS 도 Android 와 같은 통합 보관함(DocumentsWorkspaceView)이다 — 용량 카드·개수·검색·필터·목록 구조 일치. iOS 단위 렌더라 OS 상태바가 없다.')
add('서류','일정의 무료 서류 카드','pass-docs-locked','docs-card-locked',note='카드 단독 렌더 비교. 양쪽 일치.')
add('서류','일정의 유료 서류 카드','docs-detail-viewonly','docs-card-viewonly',note='Android 캡처는 일정 상세 전체(카드는 아래쪽), iOS 는 카드 단독. 보기 전용 카드 문구 「방장·배우자만 볼 수 있어요 · 서류는 수정하기에서 붙이고 지워요」 일치.')
add('서류','서류 업로드 폼','pass-docs-active','docs-card-active',action='등록',note='패스 활성, 「+」(앨범)·「PDF」 칸. 실제 파일 업로드는 별도 검증 필요.')
add('서류','사진 선택기','docs-edit-photo-picker',None,action='등록',note='OS 사진 선택기 화면. iOS 대응 캡처 없음.')
add('서류','업로드 중','pass-docs-uploading','docs-card-uploading',action='등록')
add('서류','저장된 파일 목록','pass-docs-files','docs-card-files')
add('서류','서류 삭제 확인','port-document-inspector','vault-inspector-delete',action='삭제',note='파일 이름 데이터 차이. 확인 줄 「이 파일을 삭제할까요? … 취소 · 삭제하기」 일치.')
add('서류','만료된 패스','port-documents-expired','vault-expired',note='Android 캡처는 아래로 굴려 만료 안내 띠가 위로 지나갔다. iOS 는 맨 위.')
add('서류','목록 요청 실패','port-documents-error','vault-error',note='문구 세트는 양쪽 같다(「서류를 불러오지 못했어요」 / 「서류가 연결된 플랜을 확인하지 못했어요」). iOS fixture 는 모든 요청이 503 이라 방 조회에서 먼저 실패해 두 번째 문장이 보인다.')
add('서류','사진 미리보기','documents-photo-detail','vault-inspector-photo')
add('서류','PDF 미리보기','documents-pdf-detail','vault-inspector-pdf')

# 내보내기
add('내보내기','파일 형식·범위 선택','port-export-options','matched-export-options',note='Android 는 「예시 데이터」 미리보기 상태, iOS 는 「내 일정」 상태라 아래 줄 문구가 다르다. 기간 칩이 Android 는 「포/함」, iOS 는 「날짜/미정 포함」에서 꺾인다. '+SHEET)
add('내보내기','PDF 예시 미리보기','export-preview-pdf','matched-export-preview-pdf-1',note='미리보기까지 굴린 프레임. 양쪽 구성 일치.')
add('내보내기','PDF 공유 시트',None,'parity-export-pdf-share',action='외부 연동',note='OS 공유 화면. 실제 외부 전송은 실행하지 않았다.')
add('내보내기','엑셀 공유 시트',None,'parity-export-workbook-share',action='외부 연동')

# 준비 패스
for n,title in enumerate(['패스 안내','서류 보관 혜택','엑셀 혜택','결제일 알림 혜택','청첩장 혜택','플랜 선택 안내']):
    add('준비 패스',title,'intro-page-'+str(n),'matched-intro-page-'+str(n),same=True,note='양쪽 시연 시간을 6600ms로 고정한 실제 WebView 캡처.')
add('준비 패스','플랜 선택·동의','pass-plans-locked','plans-yearly',issue=True,note='화면 구성은 일치(요금제 셋·혜택·필수 동의·결제 버튼). 차이: iOS StoreKit 결제가 서버 영수증 검증과 연결되지 않아 결제 버튼이 잠겨 있다. 결제 완료 검증은 하지 않았다. '+SHEET)
add('준비 패스','평생 패스 보유','plans-lifetime','plans-lifetime',note='Android 캡처는 결제 거절 안내 줄(「이미 평생 패스가 있어 이번 결제는 승인하지 않았어요…」)이 붙은 상태, iOS 는 평생 이용 중 패널만.')
add('준비 패스','평생 패스 도구 카드','release-tools-card-profile','lifetime-profile-tools')
add('준비 패스','구매 대기','pass-plans-pending',None,action='외부 연동',issue=True,note='차이: iOS StoreKit 구매·복원이 서버 검증과 연결되지 않아 구매 대기 상태 자체가 없다.')
add('준비 패스','구매 오류','pass-plans-error',None,action='외부 연동',note='iOS StoreKit 미연결로 대응 상태 캡처 없음.')
add('준비 패스','이미 활성화된 패스','release-plans-already-active',None,note='iOS 대응 캡처 없음.')

# 알림
add('알림','이번 주 결제할 것','pass-payweek-active','matched-payweek',note='iOS 캡처는 패스 활성·잠금 두 카드를 이었다. 위쪽(활성)이 Android 와 같은 상태. 날짜 데이터 차이.')
add('알림','알림 기본 설정','reminders-default','matched-reminders-default',same=True)
add('알림','알림 권한 차단','reminders-blocked','matched-reminders-blocked',same=True)
add('알림','알림 설정 저장',None,'parity-reminders',action='수정')
add('알림','실기기 백그라운드 푸시',action='외부 연동',note='APNs/FCM 실기기 수신은 이번 시뮬레이터 비교 범위에서 미검증.')

# 청첩장 편집 — 직전 청첩장 비교에서 확정한 동일 데이터 fixture, 이번에 iOS 를 다시 찍음
for key,title,a,i in [
('layout','구성·표시·순서','inv-editor-layout-sheet','compare-editor-layout-0'),
('cover','표지 입력','inv-compare-cover','compare-editor-cover-0'),
('calendar','날짜 편집','inv-editor-focus-calendar','compare-editor-calendar-0'),
('location','장소·주소 편집','inv-compare-location','compare-editor-location-0'),
('accounts','계좌 편집','inv-editor-accounts-panel','compare-editor-accounts-0'),
('gallery','사진첩 편집','inv-editor-gallery-panel','compare-editor-gallery-0')]:
    add('청첩장 편집',title,a,i,action='수정',same=True,note='동일 데이터 fixture. 아이콘·기본 날짜 선택기는 OS 차이가 있다.')
for state,title,a in [('landing','미구매 안내','studio-landing-top'),('empty','패스 보유·생성 전','studio-empty-top'),('unpublished','저장 후·공개 전','studio-mine-unpublished-top'),('published','공개 중·하객 정원','studio-mine-published-top')]:
    add('청첩장 관리',title,a,'compare-studio-'+state+'-0',same=True)
    add('청첩장 관리',title+' · 하단', {'landing':'studio-landing-bottom','empty':'studio-empty-slots','unpublished':'studio-mine-unpublished-disclose','published':'studio-mine-items'}[state], 'compare-studio-'+state+'-720',note='스크롤 거리는 플랫폼별 콘텐츠 높이에 따라 다를 수 있다.')
add('청첩장 관리','청첩장 저장·공개 완료','inv-editor-saved','parity-invitation-published',action='등록',note='Android 는 편집기의 저장됨 띠, iOS 는 공개 직후 첫 화면(QR·주소). 같은 순간이 아니다.')
add('청첩장 관리','QR·링크 공유','studio-mine-published-share','parity-invitation-share-note',action='외부 연동',note='공개 중 QR·주소 카드. 실제 OS 공유창 캡처와 QR 디코딩 검증은 별개다.')
add('청첩장 관리','청첩장 공개 중지',None,None,action='수정',note='공개/비공개 상태 캡처는 위에 있으며 스위치 조작 직후의 양쪽 연속 캡처는 아직 없다.')
for offset,title in [(0,'표지'),(700,'초대 문구·가족'),(1300,'사진첩'),(2100,'예식 달력'),(2800,'오시는 길·계좌'),(3500,'축하 정원'),(4500,'하단')]:
    add('하객 청첩장',title,'inv-body-'+str(offset),'compare-preview-'+str(offset),same=True,note='740pt 표지·동일 데이터로 지정 거리까지 스크롤. 정원 모션은 위치 비교를 위해 정지. 끝 화면은 각 플랫폼의 최대 스크롤 위치.'+(' 오시는 길은 두 앱 모두 지도를 그리지 않고 카카오맵·네이버 지도 링크만 둔다.' if offset==2800 else ''))
add('하객 청첩장','축하 글 등록·수정·삭제',None,None,action='등록·수정·삭제',note='본문 조회 캡처와 별개로 양쪽 하객 CRUD 전후 캡처는 아직 없다.')
add('모션','등록 완료 꽃 연출','bloom-create-amount','matched-bloom-create',same=True,note='이 항목은 완료 장면 정지 캡처. 전체 시간축 일치 판정은 아니다.')
for n,t in [(1,2600),(2,2800),(3,2300),(4,2225)]:
    add('모션',f'패스 혜택 {n} · {t}ms',f'intro-demo-{n}-{t}',f'matched-intro-demo-{n}-{t}',same=True,note='양쪽 공통 재생 시각을 지정한 실제 WebView 프레임.')
for t in [1200,2450,4000]:
    add('모션',f'패스 열림 · {t}ms',f'intro-open-{t}',f'matched-intro-open-{t}',same=True)
add('모션','정원 빈 좌석','port-garden-empty','matched-garden-empty',same=True)
add('모션','하객 말풍선','port-garden-bubble','matched-garden-bubble',same=True)
add('모션','청첩장 문 열림 중','inv-guest-door-opening','compare-door-1900',note='같은 시각 프레임이 아니다. Android 캡처는 문이 거의 다 열린 뒤, iOS 는 1900ms(문이 열리는 중). iOS 1200·2600·3200ms 프레임도 있다(compare-door-*).')
add('광고·업데이트','Google 테스트 네이티브 광고','ads_real_banners','google-test-native',note='양쪽 실제 테스트 광고. 제공 소재·형식이 달라 동일 픽셀 판정 대상이 아니다.')
add('광고·업데이트','Google 테스트 배너',None,'google-test-banner')
add('광고·업데이트','업데이트 권고','update-card','update-card',issue=True,note='모양은 일치(iOS 는 둘째 문장 줄바꿈 위치만 다름). 차이: iOS 는 모양만 있고 App Store 버전 확인이 없어 실제로 뜨는 경로가 없다.')
add('광고·업데이트','강제 업데이트','update-card-force','update-card-force',issue=True,note='모양은 일치(iOS 는 「…이어서 써 / 주세요」로 한 번 더 꺾임). 차이: App Store 버전 확인이 없다.')

add('서류','서류 보관함 · 빈 목록',None,'vault-empty',note='Android 대응 캡처 없음.')
add('서류','일정 서류 · 불러오기 실패','pass-docs-error','docs-card-error',note='같은 상태가 아니다. Android 캡처는 업로드 실패(「보관 공간이 가득 찼어요…」), iOS 는 목록 받기 실패(「서류를 불러오지 못했어요」). 두 문구 모두 양쪽 코드에 있다.')

# 2026-10-14 재캡처로 새로 짝이 생긴 항목
add('신고·차단','채팅 말풍선 신고 메뉴','moderation-menu-chat','matched-moderation-menu-chat',note='채팅은 신고만, 차단 없음. 양쪽 일치.')
add('서류','일정 서류 · 만료','pass-docs-expired','docs-card-expired',note='iOS 는 「전부 내려받기」 입구가 있고 Android 캡처에는 없다 — Android 테스트가 onDownloadAll 을 넘기지 않은 fixture 차이(PassLockShotTest). 서류 개수 데이터 차이(12 / 1).')
add('내보내기','엑셀 예시 미리보기','export-preview-xlsx','matched-export-preview-xlsx-1',note='같은 상태가 아니다. Android 는 「예산 정산표」 양식, iOS 는 「일정 체크리스트」 양식을 고른 상태.')
add('커플 관리','신랑·신부 관리 시트',None,'review-native-couple-top',note='공유 시트의 「우리 둘」·해제 줄. Android 대응 캡처 없음.')
add('홈','패스 보유 · 내 청첩장',  'home-invite-mine','parity-home-garden-mine',note='같은 상태가 아니다. Android 는 공개 중 「새 축하 2 · 보기」, iOS 캡처는 비공개 「공개하기」.')
add('청첩장 편집','분위기·첫 화면','inv-editor-mood-rose','compare-editor-mood-0',action='수정',note='Android 는 「로즈」, iOS 는 「가든」을 고른 상태. 패널 구성은 같다.')
add('일정','보드 보기',None,'cal-board',note='새 캡처. Android 대응 캡처 없음.')
