import SwiftUI

struct ResultView: View {
    let result: RecommendationResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if result.picks.count < 3 {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("ごめんなさい、近くで条件に合うお店が\(result.picks.count)軒しか見つかりませんでした。3軒そろえられず申し訳ありません🙏")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                if !result.summary.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.accentColor)
                        Text(result.summary)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                ForEach(result.picks) { pick in
                    RestaurantCard(recommendation: pick)
                }

                // ホットペッパー クレジット表記（利用規約必須）
                Text("Powered by ホットペッパー Webサービス")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle(result.picks.count == 3 ? "おすすめ3軒" : "おすすめ\(result.picks.count)軒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    dismiss()
                } label: {
                    Label("条件を変えてもう一度", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
}

struct RestaurantCard: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 店舗画像
            if let url = recommendation.restaurant.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(height: 160)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 10) {
                // ロール バッジ
                if let role = recommendation.role {
                    Text(role.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor, in: Capsule())
                }

                // 店名
                Text(recommendation.restaurant.name)
                    .font(.title3)
                    .fontWeight(.bold)

                // メタ情報
                HStack(spacing: 12) {
                    Label(recommendation.restaurant.genreName, systemImage: "fork.knife")
                    Label(recommendation.restaurant.budgetLabel, systemImage: "yensign")
                    Label(walkText, systemImage: "figure.walk")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                // AI 推薦理由
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline)
                    Text(recommendation.reason)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // アクション
                HStack(spacing: 10) {
                    if let mapURL = mapURL {
                        Link(destination: mapURL) {
                            Label("地図で見る", systemImage: "map")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if let detailURL = googleSearchURL {
                        Link(destination: detailURL) {
                            Label("お店の詳細", systemImage: "arrow.up.right.square")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .padding(16)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    private var walkText: String {
        let minutes = max(1, recommendation.restaurant.distanceMeters / 80)
        return "徒歩約\(minutes)分"
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
