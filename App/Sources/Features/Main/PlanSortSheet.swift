import SwiftUI
import WPDomain

/// 웹 `app/components/PlanFilterModal.tsx` 이식.
///
/// ```
/// 아래에서 올라오는 흰 시트 · rounded-t-[32px] · px-5 pt-8 pb-10
/// [상단 그라데이션 바 h-1.5]  #ee2b8c -> #ff94a1
/// "정렬"  text-xl font-black   [X 원형 버튼 36]
/// 옵션 리스트 — 선택된 것만 #ee2b8c 흰 글씨, 나머지는 stone-50/stone-700
/// ```
///
/// 항목을 고르면 웹과 동일하게 **즉시 적용하고 시트를 닫는다.**
struct PlanSortSheet: View {
    var selected: SortOption
    var onSelect: (SortOption) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 상단 그라데이션 바
            LinearGradient(
                colors: [WPColor.primary, Color(hex: 0xFF94A1)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 6)

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                HStack {
                    Text("정렬")
                        .font(WPFont.hak(20, .black))
                        .tracking(WPFont.trackingTight(20))
                        .foregroundStyle(WPColor.textPrimary)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WPColor.gray400)
                            .frame(width: 36, height: 36)
                            .background(WPColor.gray50, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                }

                Spacer().frame(height: 24)

                ForEach(SortOption.allCases) { option in
                    let isSelected = option == selected
                    Button {
                        onSelect(option)
                        dismiss()
                    } label: {
                        Text(option.sheetLabel)
                            .font(WPFont.hak(15, .semibold))
                            .foregroundStyle(isSelected ? .white : WPColor.stone700)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                isSelected ? WPColor.primary : WPColor.stone50,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 4)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .background(Color.white)
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
    }
}
