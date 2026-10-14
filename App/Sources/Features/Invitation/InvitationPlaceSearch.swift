import SwiftUI
import WPModels
import WPNetworking

/// Uses the same authenticated place-search proxy as Android's invitation editor.
struct InvitationPlaceSearch: View {
    let initialQuery: String
    let onClose: () -> Void
    let onSelect: (PlaceSearchResult) -> Void
    @EnvironmentObject private var env: AppEnvironment
    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("예식장 이름이나 주소", text: $query).font(invitationFont(15))
                    .submitLabel(.search).accessibilityIdentifier("invitation.placeQuery")
                Button(action: onClose) { Image(systemName: "xmark").frame(width: 40, height: 44) }.accessibilityLabel("장소 검색 닫기")
            }.padding(.leading, 12)
            if busy { ProgressView().padding(12) }
            else if let error { Text(error).font(invitationFont(12)).padding(12) }
            else if results.isEmpty { Text(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ? "두 글자 이상 적어 주세요" : "검색 결과가 없어요").font(invitationFont(12)).padding(12) }
            ForEach(results) { place in
                Button { onSelect(place) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.placeName).font(invitationFont(14, bold: true))
                        Text(place.roadAddressName?.isEmpty == false ? place.roadAddressName! : place.addressName).font(invitationFont(12)).foregroundStyle(WPColor.invMuted)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.buttonStyle(.plain)
            }
        }.foregroundStyle(WPColor.invInk).background(WPColor.invWhite, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(WPColor.invAccent))
            .onAppear { query = initialQuery }
            .task(id: query) {
                results = []; error = nil
                let value = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
                guard value.count >= 2 else { busy = false; return }
                busy = true
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    let page: PlaceSearchPage = try await env.api.send(Endpoint.searchPlaces(query: value))
                    try Task.checkCancellation()
                    results = page.list; busy = false
                } catch {
                    guard !Task.isCancelled else { return }
                    self.error = "장소를 찾지 못했어요. 검색어를 바꿔 다시 시도해 주세요."; busy = false
                }
            }
    }
}
