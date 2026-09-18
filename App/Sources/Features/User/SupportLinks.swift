import SwiftUI
import UIKit

/// 문의하기 · 개인정보처리방침 두 줄.
///
/// **앱 안에서 연락할 방법이 이 줄 하나뿐이다.** 주소는 웹 랜딩 푸터와 방침에도
/// 있지만 둘 다 읽으러 들어가는 문서이고, 랜딩은 로그인하면 다시 보이지 않는다 —
/// 쓰다가 막힌 사람이 닿는 자리는 여기다.
///
/// 방침은 로그인 여부와 **무관하게 항상** 보여야 한다. 스토어 심사에서 앱 안
/// 접근 경로를 본다.
///
/// **밑줄 두 개가 아니라 메뉴 줄이다**(시안 `docs/concepts/user-contact.html` 의
/// B안, 웹·안드로이드와 같다). 처음에는 12px 회색 밑줄이었는데, 그 생김새는
/// "안 읽어도 되는 것" 이라 사람들이 눈을 미끄러뜨린다 — 법적 고지와 같은
/// 모양이기 때문이다. 이 자리가 답해야 하는 질문은 "막힌 사람이 찾을 수 있는가"
/// 하나라, 눌리는 자리로 보이는 편이 맞다.
///
/// 화면에서 떼어 둔 이유는 `/user` 가 로그인해야 닿는 자리라 이 줄만 따로 찍어
/// 볼 수 있어야 하기 때문이다 (안드로이드 `UserSupportLinksShotTest` 와 같은 이유).
struct SupportLinks: View {
    /// 메일 앱이 없어 주소를 복사했을 때 띄우는 안내.
    @State private var copiedNotice: String?

    var body: some View {
        VStack(spacing: 0) {
            SupportRowLine()

            SupportRow(
                systemImage: "envelope",
                label: "문의하기",
                sub: "막히거나 이상한 점을 알려 주세요",
                identifier: "user.support",
                action: sendSupportMail
            )

            SupportRow(
                systemImage: "shield",
                label: "개인정보처리방침",
                identifier: "user.privacy"
            ) {
                UIApplication.shared.open(AppLinks.privacyPolicy)
            }

            if let copiedNotice {
                Text(copiedNotice)
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.fgSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    /// 문의 메일. 폼도 티켓 시스템도 만들지 않는다 — 메일 한 통이면 되고, 문의가
    /// 쌓이기 전에 만든 창구는 관리할 사람이 없어 방치된다.
    ///
    /// **본문에 버전·기기·iOS 버전을 미리 채운다.** 제보에서 가장 자주 빠지는
    /// 정보이고, 사용자에게 물으면 답이 오지 않는다. 사용자가 적을 자리는 맨 위에
    /// 비워 둔다.
    private func sendSupportMail() {
        guard let url = AppLinks.support, UIApplication.shared.canOpenURL(url) else {
            // 메일 앱을 지운 기기가 있다. 주소를 복사해 두면 다른 데로 보낼 수 있다
            // (안드로이드도 같은 자리에서 클립보드로 떨어진다).
            UIPasteboard.general.string = AppConfig.supportEmail
            copiedNotice = "메일 앱이 없어 주소를 복사했어요 — \(AppConfig.supportEmail)"
            return
        }
        UIApplication.shared.open(url)
    }
}

/// 시안의 `.row` — 30pt 분홍 아이콘 타일 + 라벨(+보조 문구) + 오른쪽 화살표.
private struct SupportRow: View {
    var systemImage: String
    var label: String
    var sub: String?
    var identifier: String
    var action: () -> Void

    init(
        systemImage: String,
        label: String,
        sub: String? = nil,
        identifier: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.sub = sub
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(WPColor.primary)
                        .frame(width: 30, height: 30)
                        .background(
                            SupportPalette.tile,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(WPFont.hak(14.5))
                            .foregroundStyle(WPColor.textPrimary)
                        if let sub {
                            Text(sub)
                                .font(WPFont.hak(12))
                                .foregroundStyle(SupportPalette.sub)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SupportPalette.chevron)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 15)
                // 줄 전체가 눌리는 자리다. 글자에만 히트 영역이 잡히면 오른쪽
                // 빈 곳을 눌렀을 때 아무 일도 일어나지 않는다.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)

            SupportRowLine()
        }
    }
}

private struct SupportRowLine: View {
    var body: some View {
        Rectangle()
            .fill(SupportPalette.line)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// 시안 `docs/concepts/user-contact.html` 의 `--line` · `.ic` · `--ink-3` · `.chev`.
///
/// 앱 토큰에 없는 값이라 여기 둔다(안드로이드도 같은 파일에 같은 네 값을 둔다).
/// 다른 화면에서 쓸 일이 생기면 그때 `WPColor` 로 올린다.
private enum SupportPalette {
    static let line = Color(hex: 0xECEFF3)
    static let tile = Color(hex: 0xFFF2F6)
    static let sub = Color(hex: 0x7A6C74)
    static let chevron = Color(hex: 0xCFC8CD)
}
