import SwiftUI

struct ResultView: View {
    let result: RecommendationResult
    @Environment(\.dismiss) private var dismiss

    private let roleOrder: [Role] = [.honmei, .anaba, .bunan]

    var body: some View {
        ZStack {
            Trois.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Trois.cardGap) {
                    // kicker
                    HStack(spacing: 5) {
                        ForEach(roleOrder, id: \.self) { role in
                            Circle().fill(role.color).frame(width: 6, height: 6)
                        }
                        Text("あなたにおすすめの\(result.picks.count)軒")
                            .font(Trois.body(12.5, weight: .medium))
                            .tracking(0.4)
                            .foregroundStyle(Trois.accentDeep)
                    }

                    // サマリー
                    if !result.summary.isEmpty {
                        Text(result.summary)
                            .font(Trois.display(18, weight: .medium))
                            .foregroundStyle(Trois.ink)
                            .lineSpacing(10)
                            .tracking(0.3)
                    }

                    // お詫びバナー
                    if result.picks.count < 3 {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "leaf")
                                .foregroundStyle(Trois.ochreDeep)
                            Text("ごめんね、近くで条件に合うお店が\(result.picks.count)軒しか見つからなかった。条件を少しゆるめてもらえると、もっと提案できるかも。")
                                .font(Trois.body(13.5))
                                .foregroundStyle(Trois.ink)
                                .lineSpacing(5)
                        }
                        .padding(15)
                        .background(Trois.ochreTint, in: RoundedRectangle(cornerRadius: Trois.rReason))
                    }

                    ForEach(Array(result.picks.enumerated()), id: \.element.id) { index, pick in
                        RestaurantCard(recommendation: pick, role: roleOrder[safe: index] ?? .bunan)
                    }

                    // クレジット表記（変更不可）
                    Text("Powered by ホットペッパー Webサービス")
                        .font(Trois.body(11))
                        .foregroundStyle(Trois.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)

                    // リトライ
                    Button {
                        dismiss()
                    } label: {
                        Text("条件を変えてもう一度")
                            .font(Trois.body(14.5, weight: .medium))
                            .foregroundStyle(Trois.accentDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(
                        Capsule().strokeBorder(Trois.accent, lineWidth: 1.5)
                    )
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, Trois.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Trois.cream, for: .navigationBar)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RestaurantCard: View {
    let recommendation: Recommendation
    let role: Role

    var body: some View {
        HStack(spacing: 0) {
            // カラーレール
            Rectangle()
                .fill(role.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 0) {
                // 写真（フルワイド・上）
                Group {
                    if let url = recommendation.restaurant.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                placeholderImage
                            }
                        }
                    } else {
                        placeholderImage
                    }
                }
                .frame(height: 172)
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: 12) {
                    // 店名
                    Text(recommendation.restaurant.name)
                        .font(Trois.display(20, weight: .bold))
                        .foregroundStyle(Trois.ink)

                    // メタ情報
                    HStack(spacing: 6) {
                        Text(recommendation.restaurant.genreName)
                        Text("・").foregroundStyle(Trois.inkFaint)
                        Text(recommendation.restaurant.budgetLabel)
                        Text("・").foregroundStyle(Trois.inkFaint)
                        Text("徒歩\(walkMinutes)分")
                    }
                    .font(Trois.body(12.5))
                    .foregroundStyle(Trois.inkSoft)

                    // 理由ボックス
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("AI")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(role.color, in: Circle())
                            Text("あなたにおすすめの理由")
                                .font(Trois.body(11.5, weight: .medium))
                                .foregroundStyle(role.deep)
                        }
                        Text(recommendation.reason)
                            .font(Trois.body(13.5))
                            .foregroundStyle(Trois.ink)
                            .lineSpacing(7)
                    }
                    .padding(13)
                    .padding(.horizontal, 2)
                    .background(role.tint, in: RoundedRectangle(cornerRadius: Trois.rReason))

                    // アクション
                    HStack(spacing: 10) {
                        if let mapURL = mapURL {
                            Link(destination: mapURL) {
                                Label("地図で見る", systemImage: "location")
                                    .font(Trois.body(13.5, weight: .medium))
                                    .foregroundStyle(Trois.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Trois.surface, in: RoundedRectangle(cornerRadius: Trois.rActionButton))
                                    .overlay(RoundedRectangle(cornerRadius: Trois.rActionButton).strokeBorder(Trois.lineStrong, lineWidth: 1))
                            }
                        }
                        if let detailURL = googleSearchURL {
                            Link(destination: detailURL) {
                                HStack(spacing: 4) {
                                    Text("お店の詳細")
                                    Image(systemName: "arrow.right")
                                }
                                .font(Trois.body(13.5, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(role.color, in: RoundedRectangle(cornerRadius: Trois.rActionButton))
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(16)
            }
        }
        .background(Trois.surface)
        .clipShape(RoundedRectangle(cornerRadius: Trois.rCard))
        .overlay(RoundedRectangle(cornerRadius: Trois.rCard).strokeBorder(Trois.line, lineWidth: 1))
        .shadow(color: Trois.ink.opacity(0.03), radius: 2, y: 1)
        .shadow(color: Trois.ink.opacity(0.05), radius: 34, y: 14)
    }

    private var placeholderImage: some View {
        Trois.surfaceSink
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        let spacing: CGFloat = 18
                        var x: CGFloat = -geo.size.height
                        while x < geo.size.width {
                            path.move(to: CGPoint(x: x, y: geo.size.height))
                            path.addLine(to: CGPoint(x: x + geo.size.height, y: 0))
                            x += spacing
                        }
                    }
                    .stroke(Trois.line, lineWidth: 1)
                }
                .clipped()
            )
    }

    private var walkMinutes: Int {
        max(1, recommendation.restaurant.distanceMeters / 80)
    }

    private var mapURL: URL? {
        let lat = recommendation.restaurant.location.latitude
        let lon = recommendation.restaurant.location.longitude
        let query = "\(recommendation.restaurant.name) \(lat),\(lon)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(query)")
    }

    private var googleSearchURL: URL? {
        let name = recommendation.restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let address = (recommendation.restaurant.address ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=\(name)+\(address)")
    }
}
