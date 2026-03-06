import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // Background colors
    static let background = Color(hex: "0D0D0D")
    static let cardBackground = Color(hex: "1A1A1A")
    static let surfaceBackground = Color(hex: "2A2A2A")

    // Accent colors
    static let pink = Color(hex: "E91E8C")
    static let pinkLight = Color(hex: "FF69B4")
    static let orange = Color(hex: "FF8C42")
    static let yellow = Color(hex: "FFD93D")
    static let green = Color(hex: "6BCB77")
    static let blue = Color(hex: "4D96FF")
    static let purple = Color(hex: "9B59B6")

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "888888")
    static let textAccent = pink

    // Activity colors
    static let sleepColor = Color(hex: "9B7EDE")
    static let feedingColor = Color(hex: "FFD93D")
    static let diaperColor = Color(hex: "FF8C42")
    static let solidFoodColor = Color(hex: "6BCB77")
    static let breastMilkColor = Color(hex: "FF69B4")
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Activity Type Colors

extension PhysiologyLogType {
    var themeColor: Color {
        switch self {
        case .milkBreast:
            return AppTheme.breastMilkColor
        case .milkFormula:
            return AppTheme.feedingColor
        case .milkSolid:
            return AppTheme.solidFoodColor
        case .sleep:
            return AppTheme.sleepColor
        case .diaperWet, .diaperDirty:
            return AppTheme.diaperColor
        }
    }

    var cuteIcon: String {
        switch self {
        case .milkBreast:
            return "🍼"
        case .milkFormula:
            return "🍼"
        case .milkSolid:
            return "🥣"
        case .sleep:
            return "😴"
        case .diaperWet:
            return "💧"
        case .diaperDirty:
            return "💩"
        }
    }

    var chineseName: String {
        switch self {
        case .milkBreast:
            return "母乳"
        case .milkFormula:
            return "配方奶"
        case .milkSolid:
            return "断奶食品"
        case .sleep:
            return "睡觉"
        case .diaperWet:
            return "小便"
        case .diaperDirty:
            return "便便"
        }
    }
}

extension ContextEventType {
    var themeColor: Color {
        switch self {
        case .vaccine:
            return AppTheme.blue
        case .travel, .jetLag:
            return AppTheme.purple
        case .illness:
            return Color.red
        case .milestone:
            return AppTheme.yellow
        case .other:
            return AppTheme.textSecondary
        }
    }
}
