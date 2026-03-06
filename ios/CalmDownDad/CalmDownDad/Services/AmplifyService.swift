import Foundation
import SwiftUI
import Combine

// MARK: - Standalone AmplifyService (No AWS SDK Required)

class AmplifyService: ObservableObject {
    static let shared = AmplifyService()

    @Published var isConfigured = false
    @Published var configurationError: Error?

    private init() {}

    // MARK: - Configuration

    func configure() async {
        await MainActor.run {
            isConfigured = true
        }
        print("Mock mode - Amplify not configured")
    }

    // MARK: - Baby CRUD

    func listBabies() async throws -> [Baby] {
        return [MockDataService.shared.mockBaby]
    }

    func createBaby(_ input: CreateBabyInput) async throws -> Baby {
        return Baby(
            id: UUID().uuidString,
            familyId: input.familyId,
            name: input.name,
            birthDate: Configuration.dateOnlyFormatter.date(from: input.birthDate) ?? Date(),
            gender: input.gender.flatMap { BabyGender(rawValue: $0) },
            notes: input.notes
        )
    }

    func deleteBaby(id: String) async throws {
        // Mock - do nothing
    }

    // MARK: - PhysiologyLog CRUD

    func listPhysiologyLogs(babyId: String, limit: Int = 50) async throws -> [PhysiologyLog] {
        return MockDataService.shared.mockLogs
    }

    func createPhysiologyLog(_ input: CreatePhysiologyLogInput) async throws -> PhysiologyLog {
        return PhysiologyLog(
            id: UUID().uuidString,
            babyId: input.babyId,
            type: input.type.flatMap { PhysiologyLogType(rawValue: $0) },
            startTime: Configuration.iso8601DateFormatter.date(from: input.startTime) ?? Date(),
            endTime: input.endTime.flatMap { Configuration.iso8601DateFormatter.date(from: $0) },
            amount: input.amount,
            unit: input.unit.flatMap { PhysiologyLogUnit(rawValue: $0) },
            notes: input.notes
        )
    }

    // MARK: - ContextEvent CRUD

    func listContextEvents(babyId: String, limit: Int = 20) async throws -> [ContextEvent] {
        return MockDataService.shared.mockEvents
    }

    func createContextEvent(_ input: CreateContextEventInput) async throws -> ContextEvent {
        return ContextEvent(
            id: UUID().uuidString,
            babyId: input.babyId,
            type: input.type.flatMap { ContextEventType(rawValue: $0) },
            title: input.title,
            startDate: Configuration.dateOnlyFormatter.date(from: input.startDate) ?? Date(),
            endDate: input.endDate.flatMap { Configuration.dateOnlyFormatter.date(from: $0) },
            notes: input.notes
        )
    }
}

// MARK: - Errors

enum AmplifyServiceError: LocalizedError {
    case notConfigured
    case queryFailed(Error)
    case mutationFailed(Error)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Amplify is not configured"
        case .queryFailed(let error):
            return "Query failed: \(error.localizedDescription)"
        case .mutationFailed(let error):
            return "Mutation failed: \(error.localizedDescription)"
        case .parsingFailed(let message):
            return "Failed to parse response: \(message)"
        }
    }
}
