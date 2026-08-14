import SwiftUI
import WPModels
import WPNetworking
import WPUtils

/// 웹의 `/user` — 내 정보 및 설정.
///
/// - Note: 팔레트·글꼴은 웹에 맞췄지만, 항목 구성은 아직 안드로이드
///   `ui/user/UserScreen.kt` 와 1:1 대조를 마치지 않았다. 후속 패스 필요.
struct UserView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @State private var user: PlanUser?

    private var displayName: String {
        if let name = user?.name, !name.isEmpty { return name }
        return guest.name.isEmpty ? "게스트" : guest.name
    }

    private var weddingDateText: String {
        let raw = user?.weddingDate
        if let raw, let date = KstDate(dateString: raw) {
            return date.weddingDateText
        }
        if let date = guest.weddingDate {
            return date.weddingDateText
        }
        return "결혼일 미설정"
    }

    var body: some View {
        ZStack {
            WPScreenBackground()

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("Settings")
                            .font(WPFont.hak(20, .bold))
                            .foregroundStyle(WPColor.textPrimary)
                        Spacer()
                    }

                    HStack(spacing: 14) {
                        MemberAvatar(name: displayName, index: 0, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(WPFont.tmoney(18, .bold))
                                .foregroundStyle(WPColor.textPrimary)
                            Text(weddingDateText)
                                .font(WPFont.hak(13))
                                .foregroundStyle(WPColor.gray500)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(WPColor.cardBorder, lineWidth: 1)
                    )

                    VStack(spacing: 0) {
                        settingRow("알림 설정", symbol: "bell")
                        Divider().padding(.leading, 48)
                        settingRow("약관 및 정책", symbol: "doc.text")
                        Divider().padding(.leading, 48)
                        settingRow("문의하기", symbol: "envelope")
                    }
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(WPColor.cardBorder, lineWidth: 1)
                    )

                    Button {
                        Task {
                            await env.signOut()
                            guest.clear()
                        }
                    } label: {
                        Text("로그아웃")
                            .font(WPFont.hak(15))
                            .foregroundStyle(WPColor.gray500)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("user.signOut")
                }
                .padding(16)
            }
        }
        .task {
            user = try? await env.api.send(Endpoint.user(), decoding: PlanUser.self)
        }
    }

    private func settingRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(WPColor.gray500)
                .frame(width: 20)
            Text(title)
                .font(WPFont.hak(15))
                .foregroundStyle(WPColor.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WPColor.gray300)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
