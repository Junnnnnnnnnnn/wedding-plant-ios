import SwiftUI
import UIKit
import WPDomain
import WPModels

/// 피드 사진 · 내 후기 줄 · 공유 단추 — 안드로이드 `ui/feed/FeedPhotos.kt` · `FeedShare.kt` 이식.
enum FeedActionColor {
    /// 안드로이드 `WpColors.FeedActionStroke` · `FeedActionText`(웹 공유 단추)
    static let stroke = Color(hex: 0xEFE7EB)
    static let text = Color(hex: 0x665A62)
}

/// 피드 화면들이 쓰는 Material 윤곽 아이콘(24×24) — 안드로이드 `Icons.Outlined.*` 원본
enum FeedOutlinedPaths {
    /// `Icons.Outlined.Share`
    static let share = ["M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92s2.92-1.31 2.92-2.92-1.31-2.92-2.92-2.92zM18 4c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zM6 13c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm12 7.02c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1z"]
    /// `Icons.Outlined.Edit`
    static let edit = ["M14.06 9.02l.92.92L5.92 19H5v-.92l9.06-9.06M17.66 3c-.25 0-.51.1-.7.29l-1.83 1.83 3.75 3.75 1.83-1.83c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.2-.2-.45-.29-.71-.29zm-3.6 3.19L3 17.25V21h3.75L17.81 9.94l-3.75-3.75z"]
}

// MARK: - 그림 받기

/// 서명 주소로 받은 그림. 주소가 한 시간 동안 같아(정각 서명) 주소를 캐시 키로 쓴다 — 목록 썸네일을 본 뒤 상세 ·
/// 크게 보기에서 다시 받지 않는다(안드로이드 Coil 과 같은 키).
@MainActor
final class FeedImageCache {
    static let shared = FeedImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private var running: [String: Task<UIImage?, Never>] = [:]

    func cached(_ url: String) -> UIImage? { cache.object(forKey: url as NSString) }

    func load(_ url: String) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let task = running[url] { return await task.value }
        let task = Task<UIImage?, Never> {
            guard let target = URL(string: url),
                  let (data, response) = try? await URLSession.shared.data(from: target),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                  let image = UIImage(data: data) else { return nil }
            return image
        }
        running[url] = task
        let image = await task.value
        running[url] = nil
        if let image { cache.setObject(image, forKey: url as NSString) }
        return image
    }
}

/// 주소 하나를 그린다. 받기 전 · 못 받았을 때는 바탕만(안드로이드 `AsyncImage` + `Stone100` 바탕).
struct FeedRemoteImage: View {
    var url: String
    var contentMode: ContentMode = .fill
    var onFailure: () -> Void = {}

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image = image ?? FeedImageCache.shared.cached(url) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            }
        }
        .task(id: url) {
            guard FeedImageCache.shared.cached(url) == nil else { return }
            image = await FeedImageCache.shared.load(url)
            if image == nil { onFailure() }
        }
    }
}

// MARK: - 내 후기 줄

/// 내 후기의 `👍 도움이 됐어요 N` — 누를 수 없는 글자다. 내 글에 "도움이 돼요" 를 누르면 도움순이 부풀려지는데
/// **서버가 아직 자기 글 투표를 막지 않아** 화면에서 단추를 없앤다(웹 `FeedCard` · 2026-10-22 사용자 지적).
/// 0 이어도 낸다. 숫자는 사용자 콘텐츠 글꼴(Tmoney).
struct HelpfulCount: View {
    var count: Int

    var body: some View {
        HStack(spacing: 0) {
            WPMaterialIcon(kind: .thumbUp).frame(width: 14, height: 14)
            Color.clear.frame(width: 6, height: 1)
            Text("도움이 됐어요").wpTypography(12.5, .bold)
            Color.clear.frame(width: 6, height: 1)
            Text("\(count)").font(WPFont.tmoney(12.5, .bold))
        }
        .foregroundStyle(WPColor.gray500)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("feed.helpfulCount")
    }
}

// MARK: - 공유

/// `공유하기` — 웹 후기 주소(`/feed/{id}`)를 시스템 공유 시트로 보낸다(안드로이드 `FeedShareButton`, b64cfe7).
struct FeedShareButton: View {
    var post: FeedPost

    private var link: String { "\(AppConfig.webBaseURL)/feed/\(post.id)" }

    var body: some View {
        ShareLink(item: "\(post.title) 후기\n\(link)", subject: Text("\(post.title) 후기 · 웨딩 플랜트")) {
            HStack(spacing: 6) {
                WPMaterialPathIcon(paths: FeedOutlinedPaths.share, size: 14, color: FeedActionColor.text)
                Text("공유하기").wpTypography(12.5, .bold).foregroundStyle(FeedActionColor.text)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(Capsule().strokeBorder(FeedActionColor.stroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feed.share.\(post.id)")
    }
}

// MARK: - 목록 썸네일 · 상세 격자

/// 목록 카드의 썸네일 줄(64 · 둥근 12 · 간격 6). **카드 전체가 상세로 가는 문이라 썸네일은 꾸밈이다** — 누르면 그냥
/// 상세로 가고 스크린 리더 설명도 비운다. 금액 열을 밀거나 카드를 키우지 않는다(이 목록에서 하는 일은 금액 훑기).
struct FeedThumbnails: View {
    var images: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(images.prefix(FeedRules.maxPhotos).enumerated()), id: \.offset) { _, url in
                FeedRemoteImage(url: url)
                    .frame(width: 64, height: 64)
                    .background(WPColor.stone100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }
}

/// 상세의 3열 정사각 격자(간격 8 · 둥근 16). 누르면 앱 안 검정 전체 화면으로 크게 본다. 비면 통째로 내지 않는다.
struct FeedPhotoGrid: View {
    var post: FeedPost
    @State private var viewing: Int?

    private var images: [String] { Array(post.images.prefix(FeedRules.maxPhotos)) }

    var body: some View {
        if !images.isEmpty {
            VStack(spacing: 0) {
                Color.clear.frame(height: 16)
                HStack(spacing: 8) {
                    ForEach(0..<FeedRules.maxPhotos, id: \.self) { index in
                        if index < images.count {
                            Button { viewing = index } label: {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(FeedRemoteImage(url: images[index]))
                                    .background(WPColor.stone100)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(post.title) 후기 사진 \(index + 1)")
                            .accessibilityIdentifier("feed.photo.\(index + 1)")
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .fullScreenCover(item: Binding(get: { viewing.map(ViewerStart.init) }, set: { viewing = $0?.index })) { start in
                FeedPhotoViewer(images: images, title: post.title, start: start.index) { viewing = nil }
            }
        }
    }

    private struct ViewerStart: Identifiable { let index: Int; var id: Int { index } }
}

/// 크게 보기 — 검정 바탕, 옆으로 넘기면 `2 / 3`. **내려받기 단추는 두지 않는다**(남의 사진일 수 있다).
/// 안드로이드 `FeedPhotoViewer`(서류의 `PhotoViewer` 는 파일에 묶여 있어 따로 둔다).
struct FeedPhotoViewer: View {
    var images: [String]
    var title: String
    var start: Int
    var onDismiss: () -> Void

    @State private var page = 0
    @State private var failed: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(title) 후기 사진 \(page + 1)").wpTypography(14).foregroundStyle(.white)
                    Text("\(page + 1) / \(images.count)").font(WPFont.tmoney(12)).foregroundStyle(.white.opacity(0.6))
                        .accessibilityIdentifier("feed.viewer.page")
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    WPLucideIcon(paths: ["M18 6 6 18", "m6 6 12 12"], size: 24, color: .white)
                        .frame(width: 48, height: 48).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")
                .accessibilityIdentifier("feed.viewer.close")
            }
            .padding(.leading, 20).padding(.trailing, 8)
            TabView(selection: $page) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                    ZStack {
                        FeedRemoteImage(url: url, contentMode: .fit) { failed.insert(index) }
                            .accessibilityLabel("\(title) 후기 사진 \(index + 1)")
                        if failed.contains(index) {
                            Text("사진을 불러오지 못했어요. 후기를 다시 열어 주세요.").wpTypography(13).foregroundStyle(.white)
                                .multilineTextAlignment(.center).padding(24)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityIdentifier("feed.viewer.pager")
        }
        .background(Color.black.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed.viewer")
        .onAppear { page = min(max(0, start), max(0, images.count - 1)) }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
    }
}
