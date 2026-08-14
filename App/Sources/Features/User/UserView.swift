import SwiftUI
import WPModels
import WPNetworking

/// 웹의 `/user` — 내 정보 및 설정.
struct UserView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var user: PlanUser?

    var body: some View {
        NavigationStack {
            ZStack {
                WP.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(WP.accentSoft)
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Text(String((user?.name ?? "?").prefix(1)))
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(WP.accent)
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user?.name ?? "게스트")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(WP.textPrimary)
                                    Text(user?.weddingDate ?? "결혼일 미설정")
                                        .font(.system(size: 13))
                                        .foregroundStyle(WP.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .wpCard()

                        VStack(spacing: 0) {
                            settingRow("알림 설정", icon: "bell")
                            Divider().padding(.leading, 44)
                            settingRow("약관 및 정책", icon: "doc.text")
                            Divider().padding(.leading, 44)
                            settingRow("문의하기", icon: "envelope")
                        }
                        .background(WP.surface)
                        .clipShape(RoundedRectangle(cornerRadius: WP.cardRadius, style: .continuous))

                        Button {
                            Task { await env.signOut() }
                        } label: {
                            Text("로그아웃")
                                .font(.system(size: 15))
                                .foregroundStyle(WP.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(WP.surface)
                                .clipShape(RoundedRectangle(cornerRadius: WP.cardRadius, style: .continuous))
                        }
                        .accessibilityIdentifier("user.signOut")
                    }
                    .padding(16)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            user = try? await env.api.send(Endpoint.user(), decoding: PlanUser.self)
        }
    }

    private func settingRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(WP.textSecondary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(WP.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WP.separator)
        }
        .padding(.horizontal, WP.padding)
        .padding(.vertical, 15)
    }
}
