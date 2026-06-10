import Foundation

struct ClaudeService {
    private let apiKey: String
    private let model = "claude-haiku-4-5-20251001"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func selectThree(from restaurants: [Restaurant], query: UserQuery, weather: WeatherInfo?) async throws -> (summary: String, picks: [Recommendation]) {
        guard !restaurants.isEmpty else { throw APIError.noResults }

        let restaurantList = restaurants.prefix(10).enumerated().map { i, r in
            """
            \(i + 1). id=\(r.id) 店名=\(r.name) ジャンル=\(r.genreName) 予算=\(r.budgetLabel) 徒歩約\(max(1, r.distanceMeters / 80))分
            """
        }.joined(separator: "\n")

        let conditionText = buildConditionText(query: query)
        let contextText = buildContextText(weather: weather)

        let prompt = """
        あなたはグルメコンシェルジュです。以下の候補店リストから、ユーザーの条件に最も合う3軒を選んでください。

        【ユーザー条件】
        \(conditionText)

        【現在の状況】
        \(contextText)

        【候補店リスト】
        \(restaurantList)

        【出力形式】
        必ず以下のJSONオブジェクトの形で返してください。他のテキストは不要です。
        {
          "summary": "なぜこの3軒を選んだのか全体を1〜2文で説明（ユーザーの条件を踏まえた選定方針）",
          "picks": [
            {
              "id": "店舗ID",
              "reason": "推薦理由（1〜2文。なぜこの店を選んだか具体的に）",
              "role": "本命 or 穴場 or 無難"
            },
            ...
          ]
        }

        ルール:
        - 必ずちょうど3軒を選ぶ（候補が3軒未満なら全て選ぶ）
        - 各役割（本命・穴場・無難）を1軒ずつ割り当てる
        - summary は3軒全体を選んだ理由・方針を述べる（個別の理由とは別の視点で）
        - 推薦理由・summaryともに「近いから」「安いから」「予算内だから」のような距離・価格を主理由にしない（条件を満たすのは前提なので、それ自体は理由にならない）
        - 代わりに、気温・天気・季節・曜日（週の真ん中だから精をつけよう、金曜だから贅沢しよう、寒いから温かい物が食べたくなる、など）といった「いまこの瞬間にこの店を選ぶ気分的な必然性」を、多少こじつけでも自然な物語として理由づけに使う
        - 各店の特徴（ジャンル・雰囲気など）と、状況（気温・天気・曜日）を組み合わせて、説得力のある"その気にさせる"理由を作る
        - コンビニが候補に含まれる場合、イートインや軽食として自然に提案してよい（「手軽に済ませたい」「時間がない」などの気分に合う場合に選ぶ）
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.httpError(statusCode: 0)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = decoded.content.first?.text else { throw APIError.httpError(statusCode: 0) }

        return try parseRecommendations(json: text, restaurants: restaurants)
    }

    private func buildContextText(weather: WeatherInfo?) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(EEEE) H時"
        let now = formatter.string(from: Date())

        var lines = ["現在日時: \(now)"]
        if let weather {
            lines.append("付近の気温: 約\(Int(weather.temperatureCelsius.rounded()))℃")
            lines.append("付近の天気: \(weather.weatherText)")
        } else {
            lines.append("天気情報: 取得できなかったため、季節感や曜日から自然に推測してよい")
        }
        return lines.joined(separator: "\n")
    }

    private func buildConditionText(query: UserQuery) -> String {
        var lines = ["徒歩\(query.walkMinutes)分以内"]
        if let budget = query.budget { lines.append("予算: \(budget.rawValue)") }
        if !query.moods.isEmpty { lines.append("今の気分: \(query.moods.map { $0.rawValue }.joined(separator: "・"))") }
        if let scene = query.diningScene { lines.append("シーン: \(scene.rawValue)") }
        if !query.genres.isEmpty { lines.append("希望ジャンル: \(query.genres.map { $0.rawValue }.joined(separator: "・"))") }
        if let freeText = query.freeText, !freeText.isEmpty { lines.append("ユーザーの自由記述（最優先で考慮すること）: \(freeText)") }
        return lines.joined(separator: "\n")
    }

    private func parseRecommendations(json: String, restaurants: [Restaurant]) throws -> (summary: String, picks: [Recommendation]) {
        // JSON部分だけ抽出
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}") else {
            throw APIError.httpError(statusCode: 0)
        }
        let jsonString = String(trimmed[start...end])
        guard let data = jsonString.data(using: .utf8) else { throw APIError.httpError(statusCode: 0) }

        let parsed = try JSONDecoder().decode(ParsedResponse.self, from: data)
        let restaurantMap = Dictionary(uniqueKeysWithValues: restaurants.map { ($0.id, $0) })

        let recommendations = parsed.picks.compactMap { pick -> Recommendation? in
            guard let restaurant = restaurantMap[pick.id] else { return nil }
            let role: RecommendationRole? = switch pick.role {
            case "本命": .honmei
            case "穴場": .anaba
            case "無難": .bunan
            default: nil
            }
            return Recommendation(id: pick.id, restaurant: restaurant, reason: pick.reason, role: role)
        }
        return (parsed.summary, recommendations)
    }

    private struct ParsedResponse: Decodable {
        let summary: String
        let picks: [PickItem]
    }

    private struct PickItem: Decodable {
        let id: String
        let reason: String
        let role: String
    }

    private struct ClaudeResponse: Decodable {
        let content: [Content]
        struct Content: Decodable {
            let text: String
        }
    }
}
