import SwiftUI
import WPDomain
import WPModels
import WPNetworking

/// 홈의 초대 띠에서 여는 시트. 온보딩의 `함께할 사람` 단계와 **같은 링크**를 보낸다.
///
/// **`?as=spouse` 가 빠지면 배우자로 부르고도 상대가 `READ` 로 들어온다** —
/// 초대 링크가 역할을 지닌다. 링크 조립은 `ShareLink.inviteURL` 한 곳이다.
///
/// 조언자(`READ`)로 부르는 길도 함께 둔다. 남의 플랜을 같이 보며 거드는 자리라
/// 귀속이 아니고, 받는 사람은 자기 플랜을 그대로 둔다.
struct SpouseInviteSheet: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var code: String?
    @State private var loading = true
    @State private var shareTarget: ShareTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("누구와 함께 준비하세요?")
                        .font(WPFont.hak(20, .bold))
                        .foregroundStyle(WPColor.textPrimary)

                    Spacer().frame(height: 8)

                    Text("신랑·신부는 일정과 예산을 같이 고칠 수 있어요")
                        .font(WPFont.hak(13.5))
                        .foregroundStyle(WPColor.fgSubtle)

                    Spacer().frame(height: 22)

                    if loading {
                        SkeletonBox(height: 68, corner: 16)
                        Spacer().frame(height: 10)
                        SkeletonBox(height: 68, corner: 16)
                    } else if code == nil {
                        Text("초대 링크를 만들지 못했어요. 잠시 후 다시 시도해 주세요.")
                            .font(WPFont.hak(13))
                            .foregroundStyle(WPColor.fgSubtle)
                    } else {
                        inviteCard(
                            title: "신랑 · 신부를 부를게요",
                            body: "일정과 예산을 같이 고칩니다",
                            asSpouse: true
                        )
                        Spacer().frame(height: 10)
                        inviteCard(
                            title: "조언자를 부를게요",
                            body: "같이 보기만 하고 고치지는 않습니다",
                            asSpouse: false
                        )
                    }
                }
                .padding(20)
            }
            .background(WPColor.background)
            .navigationTitle("함께할 사람")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .task {
            defer { loading = false }
            code = try? await env.api.send(Endpoint.shareCode(), decoding: ShareCode.self).shareCode
        }
        .sheet(item: $shareTarget) { target in
            ActivityShareSheet(items: [target.url])
        }
    }

    private func inviteCard(title: String, body: String, asSpouse: Bool) -> some View {
        Button {
            guard let code,
                  let url = ShareLink.inviteURL(
                      webBaseURL: AppConfig.webBaseURL,
                      code: code,
                      asSpouse: asSpouse
                  )
            else { return }
            shareTarget = ShareTarget(url: url)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(WPFont.hak(15, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                    Text(body)
                        .font(WPFont.hak(12.5))
                        .foregroundStyle(WPColor.fgSubtle)
                }
                Spacer(minLength: 0)
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WPColor.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                asSpouse ? Color(hex: 0xFFF7FA) : Color.white,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        asSpouse ? WPColor.primary.opacity(0.25) : WPColor.strokeWeak,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(asSpouse ? "invite.spouse" : "invite.reader")
    }
}

private struct ShareTarget: Identifiable, Hashable {
    var url: String
    var id: String { url }
}

/// 시스템 공유 시트.
struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
