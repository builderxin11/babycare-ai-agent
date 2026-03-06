import Foundation

// MARK: - Baby Gender

enum BabyGender: String, Codable, CaseIterable {
    case male = "MALE"
    case female = "FEMALE"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

// MARK: - Physiology Log Type

enum PhysiologyLogType: String, Codable, CaseIterable {
    case milkBreast = "MILK_BREAST"
    case milkFormula = "MILK_FORMULA"
    case milkSolid = "MILK_SOLID"
    case sleep = "SLEEP"
    case diaperWet = "DIAPER_WET"
    case diaperDirty = "DIAPER_DIRTY"

    var displayName: String {
        switch self {
        case .milkBreast: return "Breastfeed"
        case .milkFormula: return "Formula"
        case .milkSolid: return "Solid Food"
        case .sleep: return "Sleep"
        case .diaperWet: return "Wet Diaper"
        case .diaperDirty: return "Dirty Diaper"
        }
    }

    var icon: String {
        switch self {
        case .milkBreast: return "drop.fill"
        case .milkFormula: return "cup.and.saucer.fill"
        case .milkSolid: return "fork.knife"
        case .sleep: return "moon.zzz.fill"
        case .diaperWet: return "drop.triangle.fill"
        case .diaperDirty: return "leaf.fill"
        }
    }

    var category: LogCategory {
        switch self {
        case .milkBreast, .milkFormula, .milkSolid:
            return .feeding
        case .sleep:
            return .sleep
        case .diaperWet, .diaperDirty:
            return .diaper
        }
    }
}

enum LogCategory: String, CaseIterable {
    case feeding = "Feeding"
    case sleep = "Sleep"
    case diaper = "Diaper"
}

// MARK: - Physiology Log Unit

enum PhysiologyLogUnit: String, Codable, CaseIterable {
    case ml = "ML"
    case oz = "OZ"
    case minutes = "MINUTES"
    case count = "COUNT"

    var displayName: String {
        switch self {
        case .ml: return "ml"
        case .oz: return "oz"
        case .minutes: return "min"
        case .count: return ""
        }
    }
}

// MARK: - Context Event Type

enum ContextEventType: String, Codable, CaseIterable {
    case vaccine = "VACCINE"
    case travel = "TRAVEL"
    case jetLag = "JET_LAG"
    case illness = "ILLNESS"
    case milestone = "MILESTONE"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .vaccine: return "Vaccine"
        case .travel: return "Travel"
        case .jetLag: return "Jet Lag"
        case .illness: return "Illness"
        case .milestone: return "Milestone"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .vaccine: return "syringe.fill"
        case .travel: return "airplane"
        case .jetLag: return "clock.arrow.circlepath"
        case .illness: return "cross.case.fill"
        case .milestone: return "star.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Risk Level

enum RiskLevel: String, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"

    var displayName: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - Health Status

enum HealthStatus: String, Codable {
    case healthy = "healthy"
    case monitor = "monitor"
    case concern = "concern"

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .monitor: return "Monitor"
        case .concern: return "Concern"
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .monitor: return "eye.fill"
        case .concern: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .healthy: return "green"
        case .monitor: return "orange"
        case .concern: return "red"
        }
    }
}

// MARK: - Trend Direction

enum TrendDirection: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"

    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var color: String {
        switch self {
        case .improving: return "green"
        case .stable: return "blue"
        case .declining: return "orange"
        }
    }
}

// MARK: - Source Status Code

enum SourceStatusCode: String, Codable {
    case ok = "ok"
    case degraded = "degraded"
    case fallback = "fallback"
    case skipped = "skipped"
}
