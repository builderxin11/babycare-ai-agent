import Foundation

// MARK: - Standalone AgentAPIService (Mock Only)

actor AgentAPIService {
    static let shared = AgentAPIService()

    private init() {}

    // MARK: - Ask Agent

    func askAgent(question: String, baby: Baby) async throws -> ParentingAdvice {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Return mock advice with the actual question
        let mockAdvice = MockDataService.shared.mockAdvice
        return ParentingAdvice(
            question: question,
            summary: mockAdvice.summary,
            keyPoints: mockAdvice.keyPoints,
            actionItems: mockAdvice.actionItems,
            riskLevel: mockAdvice.riskLevel,
            confidenceScore: mockAdvice.confidenceScore,
            citations: mockAdvice.citations,
            sourcesUsed: mockAdvice.sourcesUsed,
            isDegraded: mockAdvice.isDegraded,
            rawSources: mockAdvice.rawSources,
            disclaimer: mockAdvice.disclaimer
        )
    }

    // MARK: - Generate Daily Report

    func generateReport(baby: Baby, date: Date = Date()) async throws -> DailyReport {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return MockDataService.shared.mockReport
    }

    // MARK: - Health Check

    func healthCheck() async throws -> Bool {
        return true
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
