import Foundation

struct DailyReport: Codable, Identifiable {
    var id: String { "\(babyId)-\(reportDateString)" }

    let babyId: String
    let babyName: String
    let reportDate: Date
    let healthStatus: HealthStatus
    let confidenceScore: Double
    let trendDirection: TrendDirection
    let summary: String
    let observations: [String]
    let actionItems: [String]
    let warnings: [String]
    let citations: [Citation]
    let dataSnapshot: [String: AnyCodable]
    let baselineSnapshot: [String: AnyCodable]
    let generatedAt: Date
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case babyId = "baby_id"
        case babyName = "baby_name"
        case reportDate = "report_date"
        case healthStatus = "health_status"
        case confidenceScore = "confidence_score"
        case trendDirection = "trend_direction"
        case summary
        case observations
        case actionItems = "action_items"
        case warnings
        case citations
        case dataSnapshot = "data_snapshot"
        case baselineSnapshot = "baseline_snapshot"
        case generatedAt = "generated_at"
        case disclaimer
    }

    init(
        babyId: String,
        babyName: String,
        reportDate: Date,
        healthStatus: HealthStatus = .healthy,
        confidenceScore: Double = 0.8,
        trendDirection: TrendDirection = .stable,
        summary: String,
        observations: [String] = [],
        actionItems: [String] = [],
        warnings: [String] = [],
        citations: [Citation] = [],
        dataSnapshot: [String: AnyCodable] = [:],
        baselineSnapshot: [String: AnyCodable] = [:],
        generatedAt: Date = Date(),
        disclaimer: String = "This daily report is AI-generated based on logged data. It is not a substitute for professional medical advice."
    ) {
        self.babyId = babyId
        self.babyName = babyName
        self.reportDate = reportDate
        self.healthStatus = healthStatus
        self.confidenceScore = confidenceScore
        self.trendDirection = trendDirection
        self.summary = summary
        self.observations = observations
        self.actionItems = actionItems
        self.warnings = warnings
        self.citations = citations
        self.dataSnapshot = dataSnapshot
        self.baselineSnapshot = baselineSnapshot
        self.generatedAt = generatedAt
        self.disclaimer = disclaimer
    }

    var reportDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: reportDate)
    }

    var reportDateDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: reportDate)
    }

    var confidencePercentage: Int {
        Int(confidenceScore * 100)
    }

    var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

// MARK: - Generate Report Request

struct GenerateReportRequest: Encodable {
    let babyId: String
    let babyName: String
    let reportDate: String // ISO date YYYY-MM-DD

    enum CodingKeys: String, CodingKey {
        case babyId = "baby_id"
        case babyName = "baby_name"
        case reportDate = "report_date"
    }
}
