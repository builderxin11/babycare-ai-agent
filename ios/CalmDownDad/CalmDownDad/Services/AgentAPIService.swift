import Foundation

// MARK: - AgentAPIService (Real API Calls)

actor AgentAPIService {
    static let shared = AgentAPIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Configuration.requestTimeout
        config.timeoutIntervalForResource = Configuration.resourceTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Ask Agent

    func askAgent(question: String, baby: Baby) async throws -> ParentingAdvice {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent(Configuration.Endpoints.ask)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = AskRequest(
            question: question,
            baby_id: baby.id,
            baby_name: baby.name,
            baby_age_months: baby.ageInMonths
        )

        request.httpBody = try Configuration.jsonEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentAPIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentAPIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let apiResponse = try Configuration.jsonDecoder.decode(AskResponse.self, from: data)
        return apiResponse.toParentingAdvice()
    }

    // MARK: - Generate Daily Report

    func generateReport(baby: Baby, date: Date = Date()) async throws -> DailyReport {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent(Configuration.Endpoints.report)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ReportRequest(
            baby_id: baby.id,
            baby_name: baby.name,
            baby_age_months: baby.ageInMonths
        )

        request.httpBody = try Configuration.jsonEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentAPIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentAPIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let apiResponse = try Configuration.jsonDecoder.decode(ReportResponse.self, from: data)
        return apiResponse.toDailyReport()
    }

    // MARK: - Health Check

    func healthCheck() async throws -> Bool {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent(Configuration.Endpoints.health)

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }
}

// MARK: - Request Models

private struct AskRequest: Encodable {
    let question: String
    let baby_id: String
    let baby_name: String
    let baby_age_months: Int
}

private struct ReportRequest: Encodable {
    let baby_id: String
    let baby_name: String
    let baby_age_months: Int
}

// MARK: - Response Models

private struct AskResponse: Decodable {
    let question: String
    let summary: String
    let key_points: [String]
    let action_items: [String]
    let risk_level: String
    let confidence_score: Double
    let citations: [CitationResponse]
    let sources_used: [SourceStatusResponse]
    let is_degraded: Bool
    let raw_sources: [String]
    let disclaimer: String

    func toParentingAdvice() -> ParentingAdvice {
        ParentingAdvice(
            question: question,
            summary: summary,
            keyPoints: key_points,
            actionItems: action_items,
            riskLevel: RiskLevel(rawValue: risk_level) ?? .medium,
            confidenceScore: confidence_score,
            citations: citations.map { $0.toCitation() },
            sourcesUsed: sources_used.map { $0.toSourceStatus() },
            isDegraded: is_degraded,
            rawSources: raw_sources,
            disclaimer: disclaimer
        )
    }
}

private struct CitationResponse: Decodable {
    let source_type: String
    let reference: String
    let url: String?

    func toCitation() -> Citation {
        Citation(sourceType: source_type, reference: reference, url: url)
    }
}

private struct SourceStatusResponse: Decodable {
    let source: String
    let status: String
    let message: String

    func toSourceStatus() -> SourceStatus {
        SourceStatus(
            source: source,
            status: SourceStatusCode(rawValue: status) ?? .ok,
            message: message
        )
    }
}

private struct ReportResponse: Decodable {
    let baby_id: String
    let baby_name: String
    let report_date: String
    let health_status: String
    let confidence_score: Double
    let trend_direction: String
    let summary: String
    let observations: [String]
    let action_items: [String]
    let warnings: [String]
    let citations: [CitationResponse]
    let data_snapshot: [String: Double]
    let baseline_snapshot: [String: Double]
    let generated_at: String
    let disclaimer: String

    func toDailyReport() -> DailyReport {
        let dateFormatter = ISO8601DateFormatter()

        return DailyReport(
            babyId: baby_id,
            babyName: baby_name,
            reportDate: dateFormatter.date(from: report_date) ?? Date(),
            healthStatus: HealthStatus(rawValue: health_status) ?? .healthy,
            confidenceScore: confidence_score,
            trendDirection: TrendDirection(rawValue: trend_direction) ?? .stable,
            summary: summary,
            observations: observations,
            actionItems: action_items,
            warnings: warnings,
            citations: citations.map { $0.toCitation() },
            dataSnapshot: data_snapshot,
            baselineSnapshot: baseline_snapshot,
            generatedAt: dateFormatter.date(from: generated_at) ?? Date(),
            disclaimer: disclaimer
        )
    }
}

// MARK: - Errors

enum AgentAPIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Baby Extension

extension Baby {
    var ageInMonths: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: Date())
        return components.month ?? 0
    }
}
