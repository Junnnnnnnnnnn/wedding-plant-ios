# QA 시트 (iOS)

원본은 Android 저장소 `docs/qa-sheet/`(README · `QA_SHEET.csv` · `.claude/skills/qa-sheet/SKILL.md` · `scripts/qa/qa_sheet.py`).
열 · 판정 기준 · 위험 규칙은 그대로이고, **iOS 앱 글자 · 기기 조작이 다른 줄만 고친 사본**이 `QA_SHEET_IOS.csv` 다(줄 순서 · ID 같음).
회차는 Android 저장소의 `qa_sheet.py` 로 만들고(`new --label iOS`), 이 사본을 쓰려면 회차 폴더의 `results.csv` 를 이 파일로 바꿔 넣는다.

## iOS 에서 돌릴 때 (2026-10-28 첫 회차에서 겪은 것)

- `agent-device@0.21.33` 은 **Node 20 이상**(18 은 `util.styleText` 가 없어 죽는다). 데몬이 옛 Node 로 떠 있으면 `pkill -f agent-device/dist/src/internal/daemon.js`.
- 기기는 `--udid <시뮬레이터>` 로 고정. **같은 시뮬레이터에서 xcodebuild 테스트를 돌리면 QA 앱이 꺼진다** — 테스트는 회차 끝에.
- 웹뷰 · 긴 애니메이션(패스 소개) 뒤에 스냅샷이 `circuit-disabled` 로 2~3개 요소만 나오면 데몬을 다시 띄운다.
- 참조(`@eN`)는 스냅샷 뒤 다른 동작이 끼면 만료된다(`expired ref frame`) — 누르기 직전에 다시 잡는다. `fill` 은 라벨 셀렉터가 자주 빗나가 참조로 넣는다.
- `scroll down` 은 홈 목록을 못 굴린다 — `gesture pan`. 숫자 키패드는 `keyboard dismiss` 로 안 닫힌다 — 앱의 `완료` 줄.
- 버벅임: `agent-device perf frames` 는 **연결된 실기기만**(시뮬레이터 불가). 시뮬레이터 회차는 `xcrun simctl io <udid> recordVideo` 로 움직임만 보고 버벅임 칸에 `측정 불가` 를 적는다.
- QA 계정은 저장소 밖 `~/.wp-release-tools/qa-account.json`(email · password) — 표준입력으로만 넣는다.
