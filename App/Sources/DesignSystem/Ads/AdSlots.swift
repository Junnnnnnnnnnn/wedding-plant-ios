import SwiftUI
import GoogleMobileAds
import WPDomain
import OSLog

/// 네이티브 광고의 모양 — 놓이는 목록에 맞춘다(안드로이드 `NativeAdStyle`, 기획 `docs/concepts/ads-layout.html` 보드 01).
enum NativeAdStyle {
    /// 홈 ① — 할 일 카드와 같은 회색 채움 카드. 그림 칸 없음(아이콘만, 동영상이면 동영상 칸)
    case home
    /// 피드 ③ — 후기와 같은 헤어라인 한 줄. 오른쪽에 정사각 그림 칸
    case feed
    /// 자랑하기 ④ — 자랑 카드와 같은 흰 카드. 위에 가로 그림 칸
    case brag
}

/// 받은 네이티브 광고를 **자리 이름마다** 들고 다시 쓴다 — 안드로이드 `AdsSdk.nativeAd(key)`.
///
/// 칸이 사라질 때마다 버리고 다시 받으면 스크롤로 오갈 때마다 요청이 나가고, 받는 0.5~2초 사이 칸이 비었다가
/// 끼어들어 보던 글이 밀린다. 판정이 바뀌면(`AdsService.bumpGeneration`) 통째로 버린다.
@MainActor final class NativeAdStore: NSObject, ObservableObject, NativeAdLoaderDelegate {
    static let shared = NativeAdStore()
    @Published private(set) var ads: [String: NativeAd] = [:]
    private var loaders: [String: AdLoader] = [:]
    private var loadedAt: [String: Date] = [:]
    private var failedAt: [String: Date] = [:]
    private static let log = Logger(subsystem: "app.weddingplant", category: "Ads")

    func load(_ key: String) {
        guard AdsService.shared.ready, loaders[key] == nil else { return }
        // 네이티브 광고는 한 시간이면 낡는다. 낡은 것은 새것이 올 때까지 그대로 보인다(칸이 비지 않게).
        if let at = loadedAt[key], Date().timeIntervalSince(at) < 3_600 { return }
        // 못 받은 자리는 1분 동안 다시 묻지 않는다(NO_FILL 에 매 프레임 요청하지 않게).
        if let at = failedAt[key], Date().timeIntervalSince(at) < 60 { return }
        let options = NativeAdViewAdOptions(); options.preferredAdChoicesPosition = .topRightCorner
        let loader = AdLoader(adUnitID: AdsService.nativeUnit, rootViewController: AdsService.presenter, adTypes: [.native], options: [options])
        loaders[key] = loader; loader.delegate = self; loader.load(Request())
        Self.log.notice("Native ad requested")
    }

    func release() {
        loaders.values.forEach { $0.delegate = nil }
        loaders = [:]; ads = [:]; loadedAt = [:]; failedAt = [:]
    }

    private func key(of loader: AdLoader) -> String? { loaders.first { $0.value === loader }?.key }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        guard let key = key(of: adLoader) else { return }
        loaders[key] = nil
        guard AdsService.shared.ready else { return }
        ads[key] = nativeAd; loadedAt[key] = Date(); failedAt[key] = nil
        Self.log.notice("Native ad loaded")
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        guard let key = key(of: adLoader) else { return }
        loaders[key] = nil; failedAt[key] = Date()
        Self.log.notice("Native ad unavailable, code=\((error as NSError).code)")
    }
}

/// 네이티브 광고 한 칸 — 안드로이드 `NativeAdSlot`.
///
/// **받은 광고가 있을 때만** 자리를 만든다 — 받는 중 · 못 받음 · 패스 사용 중 · 판정 전에는 아무것도 그리지 않는다
/// (빈 칸 · 뼈대를 깔지 않음, 콘텐츠 없는 광고 칸은 AdMob 정책 위반). 바깥 여백도 광고와 함께 생긴다.
struct NativeAdSlot: View {
    /// 자리 이름. 같은 이름이면 받아 둔 광고를 다시 쓴다. 접근성 id 는 `ad.<이름>` (UI 테스트가 찾음)
    let placement: String
    let style: NativeAdStyle
    /// 이 칸이 그려지면 미리 받아 둘 **다음 자리**(피드 · 자랑하기). 그 자리에 닿을 때 받기 시작하면 칸이 늦게 끼어든다
    var prefetch: String? = nil
    var horizontal: CGFloat = 16
    var top: CGFloat = 0
    var bottom: CGFloat = 0
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var ads = AdsService.shared
    @ObservedObject private var store = NativeAdStore.shared
    private var preview: Bool { AdPreview.active(isDemo: env.isDemo) }

    var body: some View {
        VStack(spacing: 0) {
            if env.adGate == .show, AdsService.enabled {
                if preview {
                    card(NativeAdAssets.preview(style), ad: nil)
                } else if ads.ready, let ad = store.ads[placement] {
                    card(NativeAdAssets(ad), ad: ad).id(ObjectIdentifier(ad))
                }
            }
        }
        .task(id: "\(ads.ready)-\(ads.generation)-\(env.adGate == .show)") {
            guard env.adGate == .show, ads.ready, !preview else { return }
            store.load(placement)
            if let prefetch { store.load(prefetch) }
        }
    }

    private func card(_ assets: NativeAdAssets, ad: NativeAd?) -> some View {
        VStack(spacing: 0) {
            NativeAdCard(ad: ad, assets: assets, style: style)
                .fixedSize(horizontal: false, vertical: true)
            // 후기 줄(`FeedCard`)과 같은 아래 헤어라인 — 목록에 섞여도 줄 간격이 같게
            if style == .feed { Hairline() }
        }
        .padding(.horizontal, horizontal).padding(.top, top).padding(.bottom, bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ad.\(placement)")
    }
}

/// 그릴 내용 — 실제 광고에서 뽑거나(SDK) 견본(데모·캡처). 모양 코드는 하나로 둔다(안드로이드 `NativeAdAssets`).
struct NativeAdAssets {
    var headline: String
    var body: String?
    var advertiser: String?
    var callToAction: String?
    var icon: UIImage?
    var starRating: Double?
    var store: String?
    var price: String?
    /// 그림 · 동영상의 가로/세로. 없으면 nil
    var mediaAspect: CGFloat?
    /// 동영상 광고 — 동영상은 그림 칸(MediaView)이 반드시 있어야 한다
    var hasVideo = false
    /// 견본에서 아이콘 자리를 회색 칸으로 보일지(실제 광고는 아이콘이 오면 그 그림, 없으면 칸 자체가 없음)
    var placeholderIcon = false

    init(headline: String, body: String?, advertiser: String?, callToAction: String?, icon: UIImage? = nil,
         starRating: Double? = nil, store: String? = nil, price: String? = nil, mediaAspect: CGFloat?,
         hasVideo: Bool = false, placeholderIcon: Bool = false) {
        self.headline = headline; self.body = body; self.advertiser = advertiser; self.callToAction = callToAction
        self.icon = icon; self.starRating = starRating; self.store = store; self.price = price
        self.mediaAspect = mediaAspect; self.hasVideo = hasVideo; self.placeholderIcon = placeholderIcon
    }

    init(_ ad: NativeAd) {
        let aspect = ad.mediaContent.aspectRatio
        self.init(headline: ad.headline ?? "", body: ad.body, advertiser: ad.advertiser, callToAction: ad.callToAction,
                  icon: ad.icon?.image, starRating: ad.starRating?.doubleValue, store: ad.store, price: ad.price,
                  mediaAspect: aspect > 0 ? aspect : nil, hasVideo: ad.mediaContent.hasVideoContent)
    }

    /// 견본 — 광고주 · 앱 이름은 지어낸 것. 안드로이드 `previewAssets` 와 같은 글자(두 앱 캡처를 나란히 비교한다)
    static func preview(_ style: NativeAdStyle) -> NativeAdAssets {
        switch style {
        case .home:
            return .init(headline: "모아 가계부 — 둘이 쓰는 예산", body: "결혼 준비 비용을 함께 기록하고 나눠 보세요",
                         advertiser: "모아랩스", callToAction: "설치", starRating: 4.6, store: "Google Play", price: "무료",
                         mediaAspect: nil, placeholderIcon: true)
        case .feed:
            return .init(headline: "본식 스냅 · 야외 촬영 패키지", body: "원본 전체 제공, 보정 40컷 포함. 상담 예약하고 날짜 잡기",
                         advertiser: "스튜디오 봄결", callToAction: "자세히 알아보기", mediaAspect: 1)
        case .brag:
            return .init(headline: "부케 · 부토니에 세트 사전 예약", body: "본식 2주 전까지 시안을 보내 드려요",
                         advertiser: "모먼트 플라워", callToAction: "자세히 보기", mediaAspect: 1.91)
        }
    }
}

private struct NativeAdCard: UIViewRepresentable {
    let ad: NativeAd?
    let assets: NativeAdAssets
    let style: NativeAdStyle
    func makeUIView(context: Context) -> NativeAdCardView { NativeAdCardView(ad: ad, assets: assets, style: style) }
    func updateUIView(_ view: NativeAdCardView, context: Context) {}
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NativeAdCardView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        return uiView.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }
}

/// 안쪽 여백이 있는 글자 칸 — 「광고」 배지와 버튼.
private final class InsetLabel: UILabel {
    var insets: UIEdgeInsets = .zero
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    // 크기는 textRect 에서만 넓힌다 — intrinsicContentSize 도 넓히면 UILabel 이 textRect 를 거쳐 한 번 더 더해 여백이 두 배가 된다.
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines lines: Int) -> CGRect {
        let rect = super.textRect(forBounds: bounds.inset(by: insets), limitedToNumberOfLines: lines)
        return rect.inset(by: UIEdgeInsets(top: -insets.top, left: -insets.left, bottom: -insets.bottom, right: -insets.right))
    }
}

/// 실제 광고면 자산마다 Google 의 `NativeAdView` 에 등록한다 — 누름 · 노출 집계는 SDK 가 한다(우리 쪽 클릭 처리 없음).
/// 견본이면 같은 모양으로 그리기만 한다. 치수·색은 안드로이드 `NativeAdLayout` 그대로.
private final class NativeAdCardView: NativeAdView {
    private let ad: NativeAd?

    init(ad: NativeAd?, assets a: NativeAdAssets, style: NativeAdStyle) {
        self.ad = ad
        super.init(frame: .zero)
        switch style {
        case .home: backgroundColor = UIColor(WPColor.fill); layer.cornerRadius = 16
        case .feed: backgroundColor = .clear
        case .brag:
            backgroundColor = .white; layer.cornerRadius = 20
            layer.borderWidth = 1; layer.borderColor = UIColor(WPColor.strokeSubtle).cgColor
        }
        clipsToBounds = style != .feed

        let root = UIStackView(); root.axis = .vertical
        root.translatesAutoresizingMaskIntoConstraints = false; addSubview(root)
        let inset: UIEdgeInsets
        switch style {
        case .home: inset = .init(top: 14, left: 16, bottom: 16, right: 16); root.spacing = 10
        case .feed: inset = .init(top: 20, left: 4, bottom: 20, right: 4); root.spacing = 8
        case .brag: inset = .init(top: 16, left: 18, bottom: 18, right: 18); root.spacing = 10
        }
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset.left),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset.right),
            root.topAnchor.constraint(equalTo: topAnchor, constant: inset.top),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset.bottom),
        ])

        root.addArrangedSubview(badgeRow(a))
        switch style {
        case .home:
            // 홈 카드는 그림 칸 없이 아이콘만 — 다만 동영상 광고는 동영상 칸이 필수 요소라 둔다(안 그리면 정책 위반)
            if a.hasVideo, let aspect = a.mediaAspect { root.addArrangedSubview(media(aspect: aspect, radius: 12)) }
            root.addArrangedSubview(iconRow(a, iconSide: 44, spacing: 12, headline: 15))
            if let cta = ctaRow(a, trailing: true) { root.addArrangedSubview(cta) }
        case .feed:
            let words = vertical(spacing: 4)
            // 앱 아이콘은 오면 반드시 보여야 한다(정책: "Required if provided")
            if let icon = icon(a, side: 32) {
                let row = UIStackView(arrangedSubviews: [icon] + [meta(a)].compactMap { $0 } + [UIView()])
                row.axis = .horizontal; row.spacing = 8; row.alignment = .center
                words.addArrangedSubview(row)
            } else if let meta = meta(a) {
                words.addArrangedSubview(meta)
            }
            words.addArrangedSubview(headline(a, size: 16))
            if let body = body(a) { words.addArrangedSubview(body) }
            if let cta = ctaRow(a, trailing: false) { words.setCustomSpacing(8, after: words.arrangedSubviews.last!); words.addArrangedSubview(cta) }
            let row = UIStackView(arrangedSubviews: [words]); row.axis = .horizontal; row.spacing = 14; row.alignment = .top
            // 동영상 광고는 그림 칸이 120pt 이상이어야 온다
            if a.mediaAspect != nil {
                let m = mediaBox(radius: 12)
                NSLayoutConstraint.activate([m.widthAnchor.constraint(equalToConstant: 120), m.heightAnchor.constraint(equalToConstant: 120)])
                row.addArrangedSubview(m)
            }
            root.addArrangedSubview(row)
        case .brag:
            // 그림은 받은 비율 그대로(늘이거나 잘라 내면 정책 위반) — 너무 길쭉한 것만 칸을 묶는다
            if let aspect = a.mediaAspect { root.addArrangedSubview(media(aspect: aspect, radius: 14)) }
            root.addArrangedSubview(iconRow(a, iconSide: 40, spacing: 10, headline: 16))
            if let cta = ctaRow(a, trailing: true) { root.addArrangedSubview(cta) }
        }
        nativeAd = ad
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 조각

    private func vertical(spacing: CGFloat) -> UIStackView {
        let v = UIStackView(); v.axis = .vertical; v.spacing = spacing; v.alignment = .fill; return v
    }

    /// 글자 줄 높이는 Compose 기본(글자 크기의 1.5배)과 맞춘다 — 안드로이드와 카드 높이가 같게.
    private func label(_ text: String, size: CGFloat, bold: Bool = false, color: Color, lines: Int, lineHeight: CGFloat? = nil) -> UILabel {
        let v = InsetLabel(); v.numberOfLines = lines; v.lineBreakMode = .byTruncatingTail
        let font = WPTypeface.hak.uiFont(size, bold ? .bold : .regular)
        let height = lineHeight ?? size * 1.5
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = height; paragraph.maximumLineHeight = height
        paragraph.lineBreakMode = .byTruncatingTail
        v.attributedText = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: UIColor(color), .paragraphStyle: paragraph,
            .baselineOffset: (height - font.lineHeight) / 4,
        ])
        return v
    }

    /// 「광고」 배지 + 광고주. 오른쪽 위 모서리(28pt)는 비워 둔다 — SDK 가 AdChoices 를 그 자리에 얹는다.
    private func badgeRow(_ a: NativeAdAssets) -> UIView {
        let badge = InsetLabel()
        badge.insets = .init(top: 1, left: 5, bottom: 1, right: 5)
        badge.text = "광고"; badge.font = WPTypeface.hak.uiFont(11, .bold); badge.textColor = UIColor(WPColor.adBadgeInk)
        badge.backgroundColor = .white; badge.layer.cornerRadius = 4; badge.layer.masksToBounds = true
        badge.layer.borderWidth = 1; badge.layer.borderColor = UIColor(WPColor.adBadgeLine).cgColor
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [badge]); row.axis = .horizontal; row.spacing = 6; row.alignment = .center
        if let advertiser = a.advertiser {
            let v = label(advertiser, size: 12, color: WPColor.fgSubtle, lines: 1)
            row.addArrangedSubview(v)
            if ad != nil { advertiserView = v }
        }
        row.addArrangedSubview(UIView())
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = .init(top: 0, leading: 0, bottom: 0, trailing: 28)
        return row
    }

    private func headline(_ a: NativeAdAssets, size: CGFloat) -> UILabel {
        // 정책은 제목 25자 전에 자르지 말라고 한다 — 좁은 피드 줄에서도 들어가게 세 줄까지
        let v = label(a.headline, size: size, bold: true, color: WPColor.fgNeutral, lines: 3)
        if ad != nil { headlineView = v }
        return v
    }

    private func body(_ a: NativeAdAssets) -> UILabel? {
        guard let text = a.body else { return nil }
        // 본문도 정책 최소치(90자 · 한글은 그 절반쯤) 전에 자르지 않게 네 줄까지
        let v = label(text, size: 13, color: WPColor.fgMuted, lines: 4, lineHeight: 19)
        if ad != nil { bodyView = v }
        return v
    }

    /// 별점 · 스토어 · 가격 — 앱 설치 광고에만 온다
    private func meta(_ a: NativeAdAssets) -> UIView? {
        guard a.starRating != nil || a.store != nil || a.price != nil else { return nil }
        let row = UIStackView(); row.axis = .horizontal; row.spacing = 5; row.alignment = .center
        if let rating = a.starRating {
            let full = Int(min(5, max(0, rating)).rounded())
            let v = UILabel(); v.text = String(repeating: "★", count: full) + String(repeating: "☆", count: 5 - full)
            v.font = .systemFont(ofSize: 11); v.textColor = UIColor(WPColor.adStar)
            row.addArrangedSubview(v); if ad != nil { starRatingView = v }
        }
        if let store = a.store {
            let v = label(store, size: 12, color: WPColor.fgMuted, lines: 1)
            row.addArrangedSubview(v); if ad != nil { storeView = v }
        }
        if let price = a.price {
            let v = label(price, size: 12, color: WPColor.fgMuted, lines: 1)
            row.addArrangedSubview(v); if ad != nil { priceView = v }
        }
        row.addArrangedSubview(UIView())
        return row
    }

    /// 아이콘 — 오면 그 그림, 없으면 **칸 자체를 만들지 않는다**(눌리는 빈 칸을 아이콘으로 등록하지 않게). 견본은 회색 칸
    private func icon(_ a: NativeAdAssets, side: CGFloat) -> UIView? {
        let view: UIView
        if let image = a.icon {
            let v = UIImageView(image: image); v.contentMode = .scaleAspectFit
            if ad != nil { iconView = v }
            view = v
        } else if a.placeholderIcon {
            view = UIView(); view.backgroundColor = UIColor(WPColor.gray200)
        } else { return nil }
        view.layer.cornerRadius = 10; view.clipsToBounds = true
        NSLayoutConstraint.activate([view.widthAnchor.constraint(equalToConstant: side), view.heightAnchor.constraint(equalToConstant: side)])
        return view
    }

    private func iconRow(_ a: NativeAdAssets, iconSide: CGFloat, spacing: CGFloat, headline size: CGFloat) -> UIView {
        let words = vertical(spacing: 3)
        words.addArrangedSubview(headline(a, size: size))
        if let meta = meta(a) { words.addArrangedSubview(meta) }
        if let body = body(a) { words.addArrangedSubview(body) }
        let row = UIStackView(); row.axis = .horizontal; row.spacing = spacing; row.alignment = .top
        if let icon = icon(a, side: iconSide) { row.addArrangedSubview(icon) }
        row.addArrangedSubview(words)
        return row
    }

    /// 그림 칸. 실제 광고는 SDK 의 `MediaView`(그림은 늘이거나 자르지 않게 aspect fit), 견본은 회색 칸
    private func mediaBox(radius: CGFloat) -> UIView {
        let view: UIView
        if let ad {
            let m = MediaView(); m.contentMode = .scaleAspectFit; m.mediaContent = ad.mediaContent
            mediaView = m; view = m
        } else {
            view = UIView(); view.backgroundColor = UIColor(WPColor.gray200)
        }
        view.clipsToBounds = true; view.layer.cornerRadius = radius
        return view
    }

    private func media(aspect: CGFloat, radius: CGFloat) -> UIView {
        let m = mediaBox(radius: radius)
        m.heightAnchor.constraint(equalTo: m.widthAnchor, multiplier: 1 / min(2, max(1, aspect))).isActive = true
        return m
    }

    /// 버튼. 분홍을 쓰지 않는다 — 분홍은 앱에서 「누를 것」이라 광고가 앱 기능처럼 읽힌다.
    /// 누름은 `NativeAdView` 가 받는다(이 칸은 터치를 받지 않음).
    private func ctaRow(_ a: NativeAdAssets, trailing: Bool) -> UIView? {
        guard let title = a.callToAction else { return nil }
        let cta = InsetLabel()
        cta.insets = .init(top: 8, left: 14, bottom: 8, right: 14)
        // 버튼 글자는 15자 전에 자르면 안 된다 — 넘치면 두 줄로
        cta.numberOfLines = 2; cta.textAlignment = .center
        cta.text = title; cta.font = WPTypeface.hak.uiFont(13, .bold); cta.textColor = UIColor(WPColor.fgNeutral)
        cta.backgroundColor = .white; cta.layer.cornerRadius = 10; cta.layer.masksToBounds = true
        cta.layer.borderWidth = 1; cta.layer.borderColor = UIColor(WPColor.strokeWeak).cgColor
        cta.isUserInteractionEnabled = false
        cta.setContentHuggingPriority(.required, for: .horizontal)
        if ad != nil { callToActionView = cta }
        let row = UIStackView(arrangedSubviews: trailing ? [UIView(), cta] : [cta, UIView()])
        row.axis = .horizontal; row.alignment = .center
        return row
    }
}

@MainActor final class BannerAdModel: NSObject, ObservableObject, BannerViewDelegate, AdSizeDelegate {
    @Published var height: CGFloat = 0
    var banner: BannerView?
    private var generation = 0
    private var width: CGFloat = 0
    func load(width: CGFloat) {
        guard AdsService.shared.ready, width > 0 else { return }
        if banner != nil, abs(self.width - width) < 1 { return }
        clear(); self.width = width; generation = AdsService.shared.generation
        // 최대 높이 100 — 300×250 같은 큰 광고가 화면 끝 한 칸을 다 차지하지 않게(안드로이드 MAX_HEIGHT_DP)
        let banner = BannerView(adSize: inlineAdaptiveBanner(width: width, maxHeight: 100))
        self.banner = banner; banner.adUnitID = AdsService.bannerUnit
        banner.rootViewController = AdsService.presenter; banner.delegate = self; banner.adSizeDelegate = self
        banner.load(Request())
    }
    func clear() { banner?.delegate = nil; banner?.adSizeDelegate = nil; banner = nil; height = 0; width = 0 }
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard bannerView === banner, generation == AdsService.shared.generation, AdsService.shared.ready else { clear(); return }
        height = min(100, max(0, bannerView.adSize.size.height))
        Logger(subsystem: "app.weddingplant", category: "Ads").notice("Banner ad loaded, height=\(self.height)")
    }
    func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize) {
        guard height > 0 else { return }; height = min(100, max(0, size.size.height))
    }
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) { height = 0 }
}

/// 인라인 적응형 배너 한 칸(일정 ② · 예산 ⑤ · 일정 상세 ⑥) — 안드로이드 `InlineBannerAd`.
/// 칸 안은 Google 이 그린다. **받기 전에는 자리가 없다** — 위아래 여백도 받은 뒤에만 생긴다.
struct InlineBannerAd: View {
    let placement: String
    var horizontal: CGFloat = 16
    var top: CGFloat = 32
    var bottom: CGFloat = 16
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var ads = AdsService.shared
    @StateObject private var model = BannerAdModel()
    @State private var width: CGFloat = 0
    private var preview: Bool { AdPreview.active(isDemo: env.isDemo) }
    var body: some View {
        VStack(spacing: 0) {
            if env.adGate == .show, AdsService.enabled {
                VStack(alignment: .leading, spacing: 6) {
                    if model.height > 0 || preview {
                        // 배너 안에도 Google 표시가 있지만 앱 목록과 섞여 보이지 않게 우리도 적는다
                        Text("광고").font(WPFont.hak(11, .bold)).foregroundStyle(WPColor.fgSubtle)
                        if preview {
                            // 견본 — 실제로는 Google 이 그리는 그림(앱 설치 · 이미지 · 글)
                            RoundedRectangle(cornerRadius: 4).fill(.white).frame(height: 64)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(WPColor.strokeWeak, lineWidth: 1))
                        } else if let banner = model.banner { BannerContainer(banner: banner).frame(height: model.height) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .padding(.top, model.height > 0 || preview ? top : 0)
                .padding(.bottom, model.height > 0 || preview ? bottom : 0)
                .padding(.horizontal, horizontal)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("ad.\(placement)")
            }
        }
        .task(id: "\(ads.ready)-\(ads.generation)-\(width)") {
            guard env.adGate == .show, ads.ready, !preview else { model.clear(); return }
            model.load(width: width)
        }
        .onDisappear { model.clear() }
    }
}
private struct BannerContainer: UIViewRepresentable {
    let banner: BannerView
    func makeUIView(context: Context) -> BannerView { banner }
    func updateUIView(_ view: BannerView, context: Context) {}
}
