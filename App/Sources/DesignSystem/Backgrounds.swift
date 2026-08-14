import SwiftUI

/// 웹 `globals.css` 의 `.grid-bg` 이식.
///
/// ```css
/// background-image: radial-gradient(#ee2b8c22 1px, transparent 1px);
/// background-size: 20px 20px;
/// ```
///
/// 20pt 타일의 중앙마다 반지름 1pt 짜리 핑크 점을 찍는다.
/// 거의 안 보이는 질감이지만, 빠지면 밋밋한 흰 배경이 되어 웹과 확연히 달라진다.
struct GridDotPattern: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 20
            let radius: CGFloat = 1
            let color = GraphicsContext.Shading.color(WPColor.gridDot)

            var y = tile / 2
            while y < size.height {
                var x = tile / 2
                while x < size.width {
                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: color)
                    x += tile
                }
                y += tile
            }
        }
        .allowsHitTesting(false)
    }
}

/// 웹 랜딩/온보딩 상단·하단의 장식 블러 원 두 개.
///
/// ```html
/// <div class="absolute top-[-10%] right-[-20%] w-80 h-80 bg-[#ee2b8c11] rounded-full blur-[100px]" />
/// <div class="absolute bottom-[-10%] left-[-20%] w-80 h-80 bg-purple-100/50 rounded-full blur-[100px]" />
/// ```
///
/// `.blur()` 대신 **중심에서 바깥으로 투명해지는 radial gradient** 로 그린다.
/// 100px 블러와 시각적으로 같으면서 렌더링 비용이 훨씬 싸다.
struct DecorativeBlurs: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                softCircle(Color(hex: 0xEE2B8C, alpha: Double(0x11) / 255))
                    .frame(width: 320, height: 320)
                    .position(x: geo.size.width + 64 - 160, y: -64 + 160)

                softCircle(Color(hex: 0xF3E8FF, alpha: 0.5))
                    .frame(width: 320, height: 320)
                    .position(x: -64 + 160, y: geo.size.height + 64 - 160)
            }
        }
        .allowsHitTesting(false)
    }

    private func softCircle(_ color: Color) -> some View {
        Circle().fill(
            RadialGradient(
                gradient: Gradient(colors: [color, color.opacity(0)]),
                center: .center,
                startRadius: 0,
                endRadius: 160
            )
        )
    }
}

/// 앱 공통 화면 배경 — 배경색 + 점 그리드.
///
/// 웹의 모든 화면이 `bg-[#fcfbfc]` 와 `.grid-bg` 를 함께 쓰므로 하나로 묶었다.
struct WPScreenBackground: View {
    /// 랜딩·설정 화면에만 있는 장식 블러
    var showsDecor: Bool = false

    var body: some View {
        ZStack {
            WPColor.background
            GridDotPattern()
            if showsDecor {
                DecorativeBlurs()
            }
        }
        .ignoresSafeArea()
    }
}
