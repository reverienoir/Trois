import Foundation
import CoreLocation
import SwiftUI

struct Coordinate {
    let latitude: Double
    let longitude: Double

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

enum BudgetRange: String, CaseIterable, Identifiable {
    case under1000 = "〜1000円"
    case under2000 = "〜2000円"
    case under3000 = "〜3000円"
    case noLimit = "上限なし"

    var id: String { rawValue }
    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }

    // ホットペッパー budget コード
    var hotpepperCode: String? {
        switch self {
        case .under1000: return "B009"
        case .under2000: return "B010"
        case .under3000: return "B011"
        case .noLimit: return nil
        }
    }
}

enum Mood: String, CaseIterable, Identifiable {
    case tired = "疲れてる"
    case wantEnergy = "元気を出したい"
    case healthy = "健康的に"
    case hearty = "がっつり"
    case light = "あっさり"
    case splurge = "贅沢したい"
    case adventurous = "冒険したい"
    case playItSafe = "失敗したくない"

    var id: String { rawValue }
    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

enum DiningScene: String, CaseIterable, Identifiable {
    case alone = "一人で"
    case withColleagues = "同僚と"
    case date = "デート"
    case family = "家族と"

    var id: String { rawValue }
    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

enum Genre: String, CaseIterable, Identifiable {
    case ramen = "ラーメン"
    case yakiniku = "焼肉"
    case curry = "カレー"
    case sobaUdon = "そば・うどん"
    case izakaya = "居酒屋"
    case fastFood = "ファストフード"
    case japanese = "和食"
    case chinese = "中華"
    case cafe = "カフェ"

    var id: String { rawValue }
    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }

    // ホットペッパー genre コード
    var hotpepperCode: String? {
        switch self {
        case .ramen: return "G013"
        case .yakiniku: return "G008"
        case .curry: return "G017"
        case .sobaUdon: return "G012"
        case .izakaya: return "G001"
        case .fastFood: return "G015"
        case .japanese: return "G004"
        case .chinese: return "G007"
        case .cafe: return "G014"
        }
    }
}

struct UserQuery {
    let location: Coordinate
    let walkMinutes: Int
    let budget: BudgetRange?
    let moods: [Mood]
    let diningScene: DiningScene?
    let genres: [Genre]
    let freeText: String?

    // 徒歩分 → ホットペッパー range (1:300m / 2:500m / 3:1000m / 4:2000m / 5:3000m)
    var hotpepperRange: Int {
        switch walkMinutes {
        case ..<7: return 2   // 〜5分 → 500m
        case ..<12: return 3  // 〜10分 → 1000m
        default: return 4     // 〜15分 → 2000m
        }
    }

    // 徒歩分 → メートル（80m/分）
    var radiusMeters: Int { walkMinutes * 80 }
}

struct Restaurant: Identifiable {
    let id: String
    let name: String
    let location: Coordinate
    let genreName: String
    let budgetLabel: String
    let distanceMeters: Int
    let imageURL: URL?
    let detailURL: URL?
    let address: String?
}

enum RecommendationRole: String {
    case honmei = "本命"
    case anaba = "穴場"
    case bunan = "無難"
}

struct Recommendation: Identifiable {
    let id: String
    let restaurant: Restaurant
    let reason: String
    let role: RecommendationRole?
}

struct RecommendationResult: Hashable {
    let picks: [Recommendation]
    let query: UserQuery
    let summary: String

    static func == (lhs: RecommendationResult, rhs: RecommendationResult) -> Bool {
        lhs.picks.map { $0.id } == rhs.picks.map { $0.id }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(picks.map { $0.id })
    }
}
