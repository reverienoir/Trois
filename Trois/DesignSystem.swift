import SwiftUI

// MARK: - Color hex helper

extension Color {
    init(hex: String, opacity: Double = 1) {
        var s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
        _ = s // silence unused warning if pattern changes
        s = ""
    }
}

// MARK: - Design tokens ("しずか" トンマナ確定)

enum Trois {
    // Palette
    static let sage = Color(hex: "7A9E7E")
    static let sageDeep = Color(hex: "5B7C60")
    static let sageTint = Color(hex: "E7EEE6")

    static let terracotta = Color(hex: "D4845A")
    static let terraDeep = Color(hex: "BB6A3F")
    static let terraTint = Color(hex: "F5E3D6")

    static let ochre = Color(hex: "C0A05E")
    static let ochreDeep = Color(hex: "A2823F")
    static let ochreTint = Color(hex: "F1E8D2")

    static let cream = Color(hex: "F5F0E8")
    static let surface = Color.white
    static let surfaceSink = Color(hex: "F1EADF")

    static let ink = Color(hex: "2E2A23")
    static let inkSoft = Color(hex: "6E6557")
    static let inkFaint = Color(hex: "A79D8C")

    static let line = Color(hex: "2E2A23", opacity: 0.09)
    static let lineStrong = Color(hex: "2E2A23", opacity: 0.16)

    // Semantic accent (= sage, "しずか" トンマナ確定。将来差し替え用にセマンティック化)
    static let accent = sage
    static let accentDeep = sageDeep
    static let accentTint = sageTint

    // Radius
    static let rCard: CGFloat = 30
    static let rChip: CGFloat = 999
    static let rField: CGFloat = 20
    static let rCTA: CGFloat = 999
    static let rReason: CGFloat = 14
    static let rActionButton: CGFloat = 12

    // Spacing
    static let screenPadding: CGFloat = 22
    static let sectionGap: CGFloat = 34
    static let cardGap: CGFloat = 20
    static let chipGap: CGFloat = 10

    // Fonts (display = Zen Maru Gothic 系の丸み、フォールバックは .rounded system)
    static func display(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 役割（色のみで区別。文字ラベルやランクは出さない）

enum Role: CaseIterable {
    case honmei
    case anaba
    case bunan

    var color: Color {
        switch self {
        case .honmei: return Trois.terracotta
        case .anaba: return Trois.sage
        case .bunan: return Trois.ochre
        }
    }
    var deep: Color {
        switch self {
        case .honmei: return Trois.terraDeep
        case .anaba: return Trois.sageDeep
        case .bunan: return Trois.ochreDeep
        }
    }
    var tint: Color {
        switch self {
        case .honmei: return Trois.terraTint
        case .anaba: return Trois.sageTint
        case .bunan: return Trois.ochreTint
        }
    }
}

extension RecommendationRole {
    /// 内部の本命/穴場/無難 を、UI表示用の色専用 Role にマッピング（文字は出さない）
    var displayRole: Role {
        switch self {
        case .honmei: return .honmei
        case .anaba: return .anaba
        case .bunan: return .bunan
        }
    }
}
