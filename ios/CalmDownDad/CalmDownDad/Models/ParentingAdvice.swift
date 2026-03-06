import Foundation

// MARK: - Citation

struct Citation: Codable, Hashable, Identifiable {
    var id: String { "\(sourceType)-\(reference)" }

    let sourceType: String
    let reference: String
    let detail: String?

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case reference
        case detail
    }

    var displayText: String {
        if let detail = detail {
            return "[\(reference)] \(detail)"
        }
        return "[\(reference)]"
    }

    var sourceIcon: String {
        switch sourceType {
        case "data_analysis": return "chart.bar.fill"
        case "book", "medical": return "book.fill"
        case "xhs_post": return "text.bubble.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Source Status

struct SourceStatus: Codable, Hashable, Identifiable {
    var id: String { source }

    let source: String
    let status: SourceStatusCode
    let message: String

    var statusIcon: String {
        switch status {
        case .ok: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.circle.fill"
        case .fallback: return "arrow.triangle.2.circlepath"
        case .skipped: return "minus.circle.fill"
        }
    }

    var statusColor: String {
        switch status {
        case .ok: return "green"
        case .degraded: return "orange"
        case .fallback: return "yellow"
        case .skipped: return "gray"
        }
    }
}

// MARK: - Parenting Advice

struct ParentingAdvice: Codable, Identifiable {
    var id: String { question }

    let question: String
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
    let riskLevel: RiskLevel
    let confidenceScore: Double
    let citations: [Citation]
    let sourcesUsed: [SourceStatus]
    let isDegraded: Bool
    let rawSources: [String]
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case question
        case summary
        case keyPoints = "key_points"
        case actionItems = "action_items"
        case riskLevel = "risk_level"
        case confidenceScore = "confidence_score"
        case citations
        case sourcesUsed = "sources_used"
        case isDegraded = "is_degraded"
        case rawSources = "raw_sources"
        case disclaimer
    }

    init(
        question: String,
        summary: String,
        keyPoints: [String] = [],
        actionItems: [String] = [],
        riskLevel: RiskLevel = .low,
        confidenceScore: Double = 0.8,
        citations: [Citation] = [],
        sourcesUsed: [SourceStatus] = [],
        isDegraded: Bool = false,
        rawSources: [String] = [],
        disclaimer: String = "This is AI-generated guidance and not a substitute for professional medical advice. Always consult your pediatrician for health concerns."
    ) {
        self.question = question
        self.summary = summary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.riskLevel = riskLevel
        self.confidenceScore = confidenceScore
        self.citations = citations
        self.sourcesUsed = sourcesUsed
        self.isDegraded = isDegraded
        self.rawSources = rawSources
        self.disclaimer = disclaimer
    }

    var confidencePercentage: Int {
        Int(confidenceScore * 100)
    }
}

// MARK: - Ask Request

struct AskRequest: Encodable {
    let question: String
    let babyId: String
    let babyName: String
    let birthDate: String // ISO date

    enum CodingKeys: String, CodingKey {
        case question
        case babyId = "baby_id"
        case babyName = "baby_name"
        case birthDate = "birth_date"
    }
}
