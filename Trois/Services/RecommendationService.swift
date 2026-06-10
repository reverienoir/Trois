import Foundation

struct RecommendationService {
    // ⚠️ APIキーは環境変数 or 設定ファイルから読む（直書き禁止）
    private let hotpepperKey: String
    private let claudeKey: String

    init() {
        // Info.plist の環境変数から読み込む
        let info = Bundle.main.infoDictionary
        self.hotpepperKey = info?["HOTPEPPER_API_KEY"] as? String ?? ""
        self.claudeKey = info?["CLAUDE_API_KEY"] as? String ?? ""
    }

    func recommend(query: UserQuery) async throws -> RecommendationResult {
        // 1. 候補取得（ファストフード選択時はMapKit、それ以外はホットペッパー）
        let candidates: [Restaurant]
        if query.genres.contains(.fastFood) {
            candidates = try await MapKitService().fetchFastFood(query: query)
        } else {
            let hotpepper = HotpepperService(apiKey: hotpepperKey)
            candidates = try await hotpepper.fetchRestaurants(query: query)
        }
        guard !candidates.isEmpty else { throw APIError.noResults }

        // 2. 周辺の天気情報を取得（取れなくても続行）
        let weather = await WeatherService().fetchWeather(at: query.location)

        // 3. Claude で3軒選定
        let claude = ClaudeService(apiKey: claudeKey)
        let (summary, picks) = try await claude.selectThree(from: candidates, query: query, weather: weather)
        guard !picks.isEmpty else { throw APIError.noResults }

        return RecommendationResult(picks: picks, query: query, summary: summary)
    }
}
