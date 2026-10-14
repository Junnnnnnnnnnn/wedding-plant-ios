import SwiftUI
import GoogleMobileAds
import WPDomain
import OSLog

enum NativeAdStyle { case home, feed, brag }

@MainActor final class NativeAdModel: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published var ad: NativeAd?
    private var loader: AdLoader?
    private var requestedAt: Date?
    private var generation = 0
    func load() {
        guard AdsService.shared.ready, loader == nil else { return }
        if let requestedAt, Date().timeIntervalSince(requestedAt) < (ad == nil ? 60 : 3_600) { return }
        ad = nil; requestedAt = Date(); generation = AdsService.shared.generation
        let options = NativeAdViewAdOptions(); options.preferredAdChoicesPosition = .topRightCorner
        let loader = AdLoader(adUnitID: AdsService.nativeUnit, rootViewController: AdsService.presenter, adTypes: [.native], options: [options])
        self.loader = loader; loader.delegate = self; loader.load(Request())
        Logger(subsystem: "app.weddingplant", category: "Ads").notice("Native ad requested")
    }
    func clear() { loader?.delegate = nil; loader = nil; ad = nil; requestedAt = nil }
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        guard adLoader === loader, AdsService.shared.ready, generation == AdsService.shared.generation else { return }
        ad = nativeAd; loader = nil
        Logger(subsystem: "app.weddingplant", category: "Ads").notice("Native ad loaded")
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        guard adLoader === loader else { return }; loader = nil; ad = nil
        Logger(subsystem: "app.weddingplant", category: "Ads").notice("Native ad unavailable, code=\((error as NSError).code)")
    }
}

struct NativeAdSlot: View {
    let placement: String
    let style: NativeAdStyle
    var horizontal: CGFloat = 16
    var top: CGFloat = 16
    var bottom: CGFloat = 16
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var ads = AdsService.shared
    @StateObject private var model = NativeAdModel()
    private var preview: Bool { env.isDemo && ProcessInfo.processInfo.arguments.contains("-WPAdPreview") }
    var body: some View {
        VStack(spacing: 0) {
            if env.adGate == .show, AdsService.enabled, model.ad != nil || preview {
                NativeAdCard(ad: model.ad, style: style)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, horizontal).padding(.top, top).padding(.bottom, bottom)
                    .accessibilityIdentifier("ad.\(placement)")
            }
        }
        .task(id: "\(ads.ready)-\(ads.generation)") {
            model.clear()
            guard env.adGate == .show, ads.ready else { return }
            model.load()
        }
        .onDisappear { model.clear() }
    }
}

private struct NativeAdCard: UIViewRepresentable {
    let ad: NativeAd?
    let style: NativeAdStyle
    func makeUIView(context: Context) -> NativeAdCardView { NativeAdCardView(ad: ad, style: style) }
    func updateUIView(_ view: NativeAdCardView, context: Context) {}
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NativeAdCardView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        return uiView.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }
}

/// Every clickable asset belongs to Google's NativeAdView; Google handles all ad taps.
private final class NativeAdCardView: NativeAdView {
    init(ad: NativeAd?, style: NativeAdStyle) {
        super.init(frame: .zero)
        backgroundColor = style == .home ? UIColor(WPColor.fill) : .white
        layer.cornerRadius = style == .home ? 16 : style == .brag ? 20 : 0
        if style == .brag { layer.borderColor = UIColor(WPColor.gray100).cgColor; layer.borderWidth = 1 }
        let root = UIStackView(); root.axis = .vertical; root.spacing = style == .feed ? 8 : 10
        root.translatesAutoresizingMaskIntoConstraints = false; addSubview(root)
        let inset: CGFloat = style == .feed ? 4 : style == .home ? 16 : 18
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset), root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset), root.topAnchor.constraint(equalTo: topAnchor, constant: style == .feed ? 20 : style == .brag ? 16 : 14), root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: style == .feed ? -20 : style == .brag ? -18 : -16)])
        func label(_ text: String?, size: CGFloat, bold: Bool = false, color: UIColor = UIColor(WPColor.fgMuted)) -> UILabel {
            let v = UILabel(); v.text = text; v.numberOfLines = 0; v.textColor = color
            v.font = UIFont(name: bold ? "HakgyoansimDunggeunmisoTTF-B" : "HakgyoansimDunggeunmisoTTF-R", size: size) ?? .systemFont(ofSize: size)
            return v
        }
        let badge = label("광고", size: 11, bold: true); badge.textAlignment = .center
        badge.layer.borderWidth = 1; badge.layer.borderColor = UIColor.gray.cgColor; badge.layer.cornerRadius = 4
        badge.widthAnchor.constraint(equalToConstant: 30).isActive = true
        let advertiser = label(ad?.advertiser ?? (ad == nil ? "테스트 광고" : nil), size: 12)
        let badgeRow = UIStackView(arrangedSubviews: [badge, advertiser, UIView()]); badgeRow.spacing = 6
        badgeRow.isLayoutMarginsRelativeArrangement = true; badgeRow.layoutMargins.right = 28
        advertiserView = advertiser; root.addArrangedSubview(badgeRow)
        let headline = label(ad?.headline ?? "둘이 함께 준비하는 웨딩", size: style == .home ? 15 : 16, bold: true, color: UIColor(WPColor.fgNeutral))
        let body = label(ad?.body ?? (ad == nil ? "광고 배치 확인용 예시입니다." : nil), size: 13)
        headlineView = headline; bodyView = body
        let words = UIStackView(arrangedSubviews: [headline, body]); words.axis = .vertical; words.spacing = style == .feed ? 4 : 3
        let meta = UIStackView(); meta.axis = .horizontal; meta.spacing = 5
        if let rating = ad?.starRating {
            let asset = label("★ \(rating)", size: 11)
            starRatingView = asset; meta.addArrangedSubview(asset)
        }
        if let store = ad?.store {
            let asset = label(store, size: 12)
            storeView = asset; meta.addArrangedSubview(asset)
        }
        if let price = ad?.price {
            let asset = label(price, size: 12)
            priceView = asset; meta.addArrangedSubview(asset)
        }
        if !meta.arrangedSubviews.isEmpty { words.insertArrangedSubview(meta, at: style == .feed ? 0 : 1) }
        let icon = UIImageView(image: ad?.icon?.image); icon.contentMode = .scaleAspectFit
        iconView = icon
        let row = UIStackView(); row.axis = .horizontal; row.spacing = style == .feed ? 14 : 12; row.alignment = .top
        if ad?.icon != nil {
            if style == .feed {
                meta.removeFromSuperview()
                let iconRow = UIStackView(arrangedSubviews: [icon, meta, UIView()]); iconRow.axis = .horizontal; iconRow.spacing = 8; iconRow.alignment = .center
                words.insertArrangedSubview(iconRow, at: 0)
            }
            else { row.addArrangedSubview(icon) }
            let side: CGFloat = style == .home ? 44 : style == .brag ? 40 : 32
            NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: side),icon.heightAnchor.constraint(equalToConstant: side)])
        }
        row.addArrangedSubview(words)
        let media = MediaView(); media.contentMode = .scaleAspectFit
        media.clipsToBounds = true; media.layer.cornerRadius = style == .brag ? 14 : 12
        if let ad { media.mediaContent = ad.mediaContent }
        mediaView = media
        let aspect = CGFloat(ad?.mediaContent.aspectRatio ?? 1.91)
        if style == .feed {
            row.addArrangedSubview(media)
            NSLayoutConstraint.activate([media.widthAnchor.constraint(equalToConstant: 120), media.heightAnchor.constraint(equalToConstant: 120)])
        } else if style == .brag || ad?.mediaContent.hasVideoContent == true {
            root.addArrangedSubview(media)
            media.heightAnchor.constraint(equalTo: media.widthAnchor, multiplier: 1 / max(1, min(2, aspect))).isActive = true
        }
        root.addArrangedSubview(row)
        if let title = ad?.callToAction ?? (ad == nil ? "자세히 보기" : nil) {
            let cta = UIButton(type: .custom); cta.setTitle(title, for: .normal)
            cta.titleLabel?.font = UIFont(name: "HakgyoansimDunggeunmisoTTF-B", size: 13)
            cta.setTitleColor(UIColor(WPColor.fgNeutral), for: .normal); cta.backgroundColor = UIColor(WPColor.gray100)
            cta.layer.cornerRadius = 8; cta.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
            cta.isUserInteractionEnabled = false; callToActionView = cta
            let titleWidth = (title as NSString).size(withAttributes: [.font: WPTypeface.hak.uiFont(13, .bold)]).width
            cta.widthAnchor.constraint(greaterThanOrEqualToConstant: ceil(titleWidth) + 28).isActive = true
            if style == .feed {
                let leftActions = UIStackView(arrangedSubviews: [cta, UIView()]); leftActions.axis = .horizontal
                words.addArrangedSubview(leftActions)
            } else {
                let actions = UIStackView(arrangedSubviews: [UIView(), cta]); actions.axis = .horizontal
                root.addArrangedSubview(actions)
            }
        }
        nativeAd = ad
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
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
        let banner = BannerView(adSize: inlineAdaptiveBanner(width: width, maxHeight: 100))
        self.banner = banner; banner.adUnitID = AdsService.bannerUnit
        banner.rootViewController = AdsService.presenter; banner.delegate = self; banner.adSizeDelegate = self
        banner.load(Request())
    }
    func clear() { banner?.delegate = nil; banner?.adSizeDelegate = nil; banner = nil; height = 0 }
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

struct InlineBannerAd: View {
    let placement: String
    var horizontal: CGFloat = 16
    var top: CGFloat = 32
    var bottom: CGFloat = 16
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var ads = AdsService.shared
    @StateObject private var model = BannerAdModel()
    @State private var width: CGFloat = 0
    private var preview: Bool { env.isDemo && ProcessInfo.processInfo.arguments.contains("-WPAdPreview") }
    var body: some View {
        VStack(spacing: 0) {
            if env.adGate == .show, AdsService.enabled {
                VStack(alignment: .leading, spacing: 6) {
                    if model.height > 0 || preview {
                        Text("광고").font(WPFont.hak(11, .bold)).foregroundStyle(WPColor.fgSubtle)
                        if preview { Rectangle().fill(.white).frame(height: 64).overlay(Rectangle().stroke(WPColor.gray100)) }
                        else if let banner = model.banner { BannerContainer(banner: banner).frame(height: model.height) }
                    }
                }
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .padding(.top, model.height > 0 || preview ? top : 0)
                .padding(.bottom, model.height > 0 || preview ? bottom : 0)
                .padding(.horizontal, horizontal)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("ad.\(placement)")
            }
        }
        .task(id: "\(ads.ready)-\(ads.generation)-\(width)") {
            guard env.adGate == .show, ads.ready else { model.clear(); return }
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
