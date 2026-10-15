import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 공개되는 것. **"일부 정보" 같은 말을 쓰지 않는다** — 글자 그대로 적는다.
/// 이 목록이 백엔드 응답(`BragDetail`)의 상한이다. 안드로이드 `BRAG_OPEN_FIELDS` 와 한 글자도 다르면 안 된다.
let bragOpenFields =
    "보일 이름(직접 정할 수 있어요) · 결혼식 날짜 · 총예산 · 카테고리별 지출과 소계 · 일정 제목 · 일정별 금액과 결제 여부 · 일정 장소"

/// 안내 시트의 규칙 넷 — 안드로이드 `BragRules`(웹 `BragToggle.tsx` 의 `RULES`) 와 같은 글자.
/// 공개 범위를 넓힐 때는 **이 문구와 개인정보처리방침을 먼저** 고친다.
private let bragRules: [(icon: [String], title: String, body: String)] = [
    // Icons.Outlined.Language
    (["M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zm6.93 6h-2.95c-.32-1.25-.78-2.45-1.38-3.56 1.84.63 3.37 1.91 4.33 3.56zM12 4.04c.83 1.2 1.48 2.53 1.91 3.96h-3.82c.43-1.43 1.08-2.76 1.91-3.96zM4.26 14C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2 0 .68.06 1.34.14 2H4.26zm.82 2h2.95c.32 1.25.78 2.45 1.38 3.56-1.84-.63-3.37-1.9-4.33-3.56zm2.95-8H5.08c.96-1.66 2.49-2.93 4.33-3.56C8.81 5.55 8.35 6.75 8.03 8zM12 19.96c-.83-1.2-1.48-2.53-1.91-3.96h3.82c-.43 1.43-1.08 2.76-1.91 3.96zM14.34 14H9.66c-.09-.66-.16-1.32-.16-2 0-.68.07-1.35.16-2h4.68c.09.65.16 1.32.16 2 0 .68-.07 1.34-.16 2zm.25 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95c-.96 1.65-2.49 2.93-4.33 3.56zM16.36 14c.08-.66.14-1.32.14-2 0-.68-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2h-3.38z"],
     "누구나 볼 수 있어요", "로그인하지 않은 사람도 볼 수 있고, 검색 결과에도 나올 수 있어요."),
    // Icons.Outlined.Refresh
    (["M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"],
     "플랜을 고치면 같이 바뀌어요", "올린 순간이 아니라 지금 플랜이 보입니다. 일정을 더하거나 장소를 붙이면 그대로 따라와요."),
    (FeedIconPaths.favoriteBorder, "다른 사람은 보기와 좋아요만", "댓글은 없어요. 우리 플랜을 남이 바꾸는 일도 없습니다."),
    // Icons.Outlined.VisibilityOff — **내릴 수 있다는 말을 빼지 말 것.** 되돌릴 방법이 있다는 유일한 안내다.
    (["M12 6c3.79 0 7.17 2.13 8.82 5.5-.59 1.22-1.42 2.27-2.41 3.12l1.41 1.41c1.39-1.23 2.49-2.77 3.18-4.53C21.27 7.11 17 4 12 4c-1.27 0-2.49.2-3.64.57l1.65 1.65C10.66 6.09 11.32 6 12 6zm-1.07 1.14L13 9.21c.57.25 1.03.71 1.28 1.28l2.07 2.07c.08-.34.14-.7.14-1.07C16.5 9.01 14.48 7 12 7c-.37 0-.72.05-1.07.14zM2.01 3.87l2.68 2.68C3.06 7.83 1.77 9.53 1 11.5 2.73 15.89 7 19 12 19c1.52 0 2.98-.29 4.32-.82l3.42 3.42 1.41-1.41L3.42 2.45 2.01 3.87zm7.5 7.5l2.61 2.61c-.04.01-.08.02-.12.02-1.38 0-2.5-1.12-2.5-2.5 0-.05.01-.08.01-.13zm-3.4-3.4l1.75 1.75c-.23.55-.36 1.15-.36 1.78 0 2.48 2.02 4.5 4.5 4.5.63 0 1.23-.13 1.77-.36l.98.98c-.88.24-1.8.38-2.75.38-3.79 0-7.17-2.13-8.82-5.5.7-1.43 1.72-2.61 2.93-3.53z"],
     "언제든 내릴 수 있어요", "끄면 바로 안 보여요. 다만 검색엔진이 이미 가져간 내용은 사라지는 데 시간이 걸려요."),
]

/// 안드로이드 `ui/brag/BragToggle.kt` 의 **폰(compact)** 이식 — 홈 목록 아래 흰 면에 붙는다.
///
/// **켜기 전에는 반드시 안내 시트를 거친다** — 피드는 철저히 익명인데 자랑하기는 닉네임이 그대로 공개돼
/// 두 화면의 규칙이 정반대다. 끄는 것은 되돌릴 수 있어 확인을 받지 않는다.
///
/// 올라가 있는 동안의 `보러 가기` 는 **폰에서 자랑하기로 들어가는 문**이다 — 지우지 말 것.
struct BragToggle: View {
    @ObservedObject var model: BragToggleViewModel
    var onOpenBrag: () -> Void
    /// 신랑·신부가 아직 등록되지 않았다(안드로이드 `MainViewModel.bragLocked`). **숨기지 않고 잠그고 이유를 적는다.**
    var locked = false
    /// 웹 `compact` — 홈 탭바 위 고정 칸. 점선 구분선 없이 스위치만 낸다.
    var compact = false

    @EnvironmentObject private var env: AppEnvironment
    @State private var showConsent = false

    var body: some View {
        BragToggleBody(status: model.status, pending: model.pending, locked: locked, compact: compact,
                       onRequestPublish: { showConsent = true },
                       onUnpublish: { Task { await model.unpublish(env: env) } },
                       onOpenBrag: onOpenBrag)
            .task { await model.load(env: env) }
            .sheet(isPresented: $showConsent) {
                BragPublishSheet(pending: model.pending, status: model.status) { title in
                    Task {
                        await model.publish(title: title, env: env)
                        if model.published { showConsent = false }
                    }
                } onDismiss: { showConsent = false }
            }
    }
}

/// 토글 면 — **상태를 갖지 않는다**(스크린샷 테스트가 그대로 그린다).
struct BragToggleBody: View {
    var status: BragMyStatus?
    var pending = false
    var locked = false
    var compact = false
    var onRequestPublish: () -> Void = {}
    var onUnpublish: () -> Void = {}
    var onOpenBrag: () -> Void = {}

    var body: some View {
        let on = status?.published == true
        // **이미 올라가 있으면 잠그지 않는다** — 켜 둔 것을 끄지 못하는 화면은 만들지 않는다.
        let isLocked = locked && !on
        VStack(alignment: .leading, spacing: 0) {
            if !compact {
                // 웹 `mt-4 border-t border-dashed border-[#f2eaee] pt-4`
                Line().stroke(Color(hex: 0xF2EAEE), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1)
                Color.clear.frame(height: 16)
            }
            // `.disabled` 를 쓰지 않는다 — 플레인 단추가 한 번 더 흐려져 안드로이드(내용만 0.6)보다 옅어진다.
            Button { guard !pending && !isLocked else { return }; if on { onUnpublish() } else { onRequestPublish() } } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("자랑하기").wpTypography(14, .bold).foregroundStyle(WPColor.bragInk)
                        Text(on ? "우리 플랜이 자랑하기에 올라가 있어요" : isLocked ? "신랑·신부를 등록하면 올릴 수 있어요" : "우리 플랜을 자랑하기에 올려요")
                            .wpTypography(12).foregroundStyle(WPColor.bragMuted)
                    }
                    Spacer(minLength: 0)
                    // 스위치 — 껐다 켜는 것이지 "제출" 이 아니라는 걸 모양으로 말한다.
                    ZStack(alignment: .leading) {
                        Capsule().fill(on ? WPColor.primary : WPColor.stone300).frame(width: 44, height: 26)
                        Circle().fill(.white).frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                            .offset(x: 3 + (on ? 18 : 0))
                            .animation(.easeOut(duration: 0.2), value: on)
                    }
                }
                // 안드로이드는 바탕 다음에 alpha — 바탕은 그대로, 내용만 흐려진다
                .opacity(pending || isLocked ? 0.6 : 1)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(hex: 0xFAF7F9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(pending || isLocked ? [.isStaticText] : [])
            .accessibilityIdentifier("brag.toggle")
            .accessibilityValue(on ? "켜짐" : "꺼짐")

            if on {
                Color.clear.frame(height: 8)
                HStack(spacing: 0) {
                    WPMaterialPathIcon(paths: FeedIconPaths.favorite, size: 14, color: WPColor.primary)
                    Color.clear.frame(width: 8)
                    Text("좋아요 ").wpTypography(12).foregroundStyle(WPColor.primary)
                    Text(verbatim: withThousands(status?.likeCount ?? 0)).wpTypography(12, .bold).foregroundStyle(WPColor.primary)
                    Spacer(minLength: 0)
                    Button(action: onOpenBrag) {
                        HStack(spacing: 0) {
                            Text("보러 가기").wpTypography(12, .bold)
                            WPMaterialPathIcon(paths: FeedIconPaths.chevronRight, size: 14, color: WPColor.primary)
                        }
                        .foregroundStyle(WPColor.primary).padding(.vertical, 2)
                    }.buttonStyle(.plain).accessibilityIdentifier("brag.open")
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(WPColor.bragPinkWeak, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) } }
    }
}

/// 켜기 전 안내 — "자랑하기에 올릴까요?" **바닥 시트**(안드로이드 `BragPublishDialog`, 웹 시안 `brag-title-mobile.html`).
///
/// 본문만 구르고 `자랑하기에 올리기 · 나중에` 는 바닥에 붙인다 — 이름을 적느라 키보드를 올려도 버튼이 보인다.
/// **보일 이름 칸이 하는 일은 입력이 아니라 경고다.** 그래서 적는 대로 바뀌는 미리보기 카드를 함께 낸다.
struct BragPublishSheet: View {
    var pending: Bool
    var status: BragMyStatus?
    var onPublish: (String) -> Void
    var onDismiss: () -> Void

    @State private var title = ""
    @State private var seeded = false

    private var fallback: String {
        let name = status?.defaultNickname.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "두 사람 이름" : name
    }
    private var shownName: String {
        let t = title.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? fallback : t
    }

    var body: some View {
        VStack(spacing: 0) {
            // 웹 `mx-auto mt-2.5 h-1 w-9 bg-[#e7dde3]` — 끌어내릴 수 있다는 표시
            Capsule().fill(Color(hex: 0xE7DDE3)).frame(width: 36, height: 4).padding(.top, 10)
            ScrollView {
                content.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            Rectangle().fill(Color(hex: 0xF4EEF1)).frame(height: 1)
            VStack(spacing: 4) {
                Button { onPublish(title) } label: {
                    Text(pending ? "올리는 중" : "자랑하기에 올리기").wpTypography(15, .bold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .opacity(pending ? 0.6 : 1)
                }.buttonStyle(.plain).disabled(pending).accessibilityIdentifier("brag.consent.confirm")
                Button(action: onDismiss) {
                    Text("나중에").wpTypography(14, .bold).foregroundStyle(WPColor.bragMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 10).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(pending)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
        .background(Color.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .presentationBackground(.white)
        .interactiveDismissDisabled(pending)
        .onAppear {
            guard !seeded else { return }
            seeded = true
            title = status?.title ?? ""
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("자랑하기에 올릴까요?".wpKeepAll).wpTypography(20, .bold).tracking(-0.6).foregroundStyle(WPColor.bragInk)
            Color.clear.frame(height: 8)
            Text("우리 플랜 한 장이 그대로 목록에 올라갑니다. 언제든 다시 내릴 수 있어요.".wpKeepAll)
                .wpTypography(14, lineHeight: 22).foregroundStyle(WPColor.bragMuted).fixedSize(horizontal: false, vertical: true)
            Color.clear.frame(height: 20)
            // 번호를 붙이지 않는다 — 순서가 아니라 성질이다.
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(bragRules.enumerated()), id: \.offset) { _, rule in
                    HStack(alignment: .top, spacing: 12) {
                        WPMaterialPathIcon(paths: rule.icon, size: 15, color: WPColor.primary)
                            .frame(width: 26, height: 26)
                            .background(WPColor.bragPinkWeak, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.title.wpKeepAll).wpTypography(14, .bold).foregroundStyle(WPColor.bragInk)
                            Text(rule.body.wpKeepAll).wpTypography(13, lineHeight: 20).foregroundStyle(WPColor.bragMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Color.clear.frame(height: 20)
            Text("자랑하기에 보일 이름").wpTypography(12, .bold).foregroundStyle(WPColor.gray400)
            Color.clear.frame(height: 6)
            ZStack(alignment: .leading) {
                if title.isEmpty {
                    Text(fallback).wpTypography(14).foregroundStyle(Color(hex: 0xA2959C)).allowsHitTesting(false)
                }
                TextField("", text: Binding(get: { title }, set: { if $0.count <= 40 { title = $0 } }))
                    .font(Font(WPTypeface.hak.uiFont(14, .bold))).foregroundStyle(WPColor.bragInk).tint(WPColor.primary)
                    .accessibilityIdentifier("brag-title")
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(WPColor.bragChipBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Color.clear.frame(height: 10)
            // 어떻게 보이는지 그림으로 말한다 — 글로만 적으면 지나친다(웹 B안).
            VStack(alignment: .leading, spacing: 8) {
                Text("이렇게 보여요").wpTypography(11, .bold).foregroundStyle(WPColor.gray400)
                VStack(alignment: .leading, spacing: 8) {
                    Text(shownName).wpTypography(15, .bold).tracking(-0.3).foregroundStyle(WPColor.bragInk).lineLimit(1)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(WPColor.bragTrack)
                            Capsule().fill(WPColor.primary).frame(width: g.size.width * 0.37)
                        }
                    }.frame(height: 6)
                }
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: 0xEFE6EA), lineWidth: 1))
            }
            .padding(12)
            .background(Color(hex: 0xFFFDFE), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: 0xEEE2E9), lineWidth: 1))
            Color.clear.frame(height: 6)
            // 조사를 붙이지 않는다 — 이름이 모음으로 끝나면 "지수으로" 가 된다. 이름(사용자 값)은 어절로 묶지 않는다.
            Text("안 적으면 ".wpKeepAll + fallback + " 이름으로 올라가요. 검색 결과에도 이 이름이 나옵니다.".wpKeepAll)
                .wpTypography(11.5, lineHeight: 18).foregroundStyle(WPColor.bragMuted).fixedSize(horizontal: false, vertical: true)
            Color.clear.frame(height: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text("공개되는 것").wpTypography(12, .bold).foregroundStyle(WPColor.gray400)
                Text(bragOpenFields.wpKeepAll).wpTypography(13, lineHeight: 20).foregroundStyle(WPColor.bragInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(WPColor.bragChipBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
