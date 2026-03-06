import Foundation
import SwiftUI
import Combine

// MARK: - AmplifyService (REST API Backend)

actor AmplifyService {
    static let shared = AmplifyService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }

    // MARK: - Baby CRUD

    func listBabies() async throws -> [Baby] {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let items = try Configuration.jsonDecoder.decode([BabyResponse].self, from: data)
        return items.map { $0.toBaby() }
    }

    func getBaby(id: String) async throws -> Baby? {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies/\(id)")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let item = try Configuration.jsonDecoder.decode(BabyResponse.self, from: data)
        return item.toBaby()
    }

    func createBaby(_ input: CreateBabyInput) async throws -> Baby {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = CreateBabyRequest(
            family_id: input.familyId,
            name: input.name,
            birth_date: input.birthDate,
            gender: input.gender,
            notes: input.notes
        )
        request.httpBody = try Configuration.jsonEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let item = try Configuration.jsonDecoder.decode(BabyResponse.self, from: data)
        return item.toBaby()
    }

    func deleteBaby(id: String) async throws {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }

    // MARK: - PhysiologyLog CRUD

    func listPhysiologyLogs(babyId: String, limit: Int = 50) async throws -> [PhysiologyLog] {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies/\(babyId)/logs")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        let (data, response) = try await session.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let items = try Configuration.jsonDecoder.decode([PhysiologyLogResponse].self, from: data)
        return items.map { $0.toPhysiologyLog() }
    }

    func createPhysiologyLog(_ input: CreatePhysiologyLogInput) async throws -> PhysiologyLog {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies/\(input.babyId)/logs")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = CreateLogRequest(
            type: input.type ?? "",
            start_time: input.startTime,
            end_time: input.endTime,
            amount: input.amount,
            unit: input.unit,
            notes: input.notes
        )
        request.httpBody = try Configuration.jsonEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let item = try Configuration.jsonDecoder.decode(PhysiologyLogResponse.self, from: data)
        return item.toPhysiologyLog()
    }

    func deletePhysiologyLog(id: String) async throws {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/logs/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }

    // MARK: - ContextEvent CRUD

    func listContextEvents(babyId: String, limit: Int = 20) async throws -> [ContextEvent] {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies/\(babyId)/events")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        let (data, response) = try await session.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let items = try Configuration.jsonDecoder.decode([ContextEventResponse].self, from: data)
        return items.map { $0.toContextEvent() }
    }

    func createContextEvent(_ input: CreateContextEventInput) async throws -> ContextEvent {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/babies/\(input.babyId)/events")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = CreateEventRequest(
            type: input.type ?? "",
            title: input.title,
            start_date: input.startDate,
            end_date: input.endDate,
            notes: input.notes,
            metadata: nil
        )
        request.httpBody = try Configuration.jsonEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let item = try Configuration.jsonDecoder.decode(ContextEventResponse.self, from: data)
        return item.toContextEvent()
    }

    func deleteContextEvent(id: String) async throws {
        let url = Configuration.agentAPIBaseURL.appendingPathComponent("/events/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmplifyServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AmplifyServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
}

// MARK: - Request Models

private struct CreateBabyRequest: Encodable {
    let family_id: String
    let name: String
    let birth_date: String
    let gender: String?
    let notes: String?
}

private struct CreateLogRequest: Encodable {
    let type: String
    let start_time: String
    let end_time: String?
    let amount: Double?
    let unit: String?
    let notes: String?
}

private struct CreateEventRequest: Encodable {
    let type: String
    let title: String
    let start_date: String
    let end_date: String?
    let notes: String?
    let metadata: [String: String]?
}

// MARK: - Response Models

private struct BabyResponse: Decodable {
    let id: String
    let familyId: String
    let name: String
    let birthDate: String
    let gender: String?
    let notes: String?

    func toBaby() -> Baby {
        Baby(
            id: id,
            familyId: familyId,
            name: name,
            birthDate: Configuration.dateOnlyFormatter.date(from: birthDate) ?? Date(),
            gender: gender.flatMap { BabyGender(rawValue: $0) },
            notes: notes
        )
    }
}

private struct PhysiologyLogResponse: Decodable {
    let id: String
    let babyId: String
    let type: String?
    let startTime: String
    let endTime: String?
    let amount: Double?
    let unit: String?
    let notes: String?

    func toPhysiologyLog() -> PhysiologyLog {
        PhysiologyLog(
            id: id,
            babyId: babyId,
            type: type.flatMap { PhysiologyLogType(rawValue: $0) },
            startTime: Configuration.iso8601DateFormatter.date(from: startTime) ?? Date(),
            endTime: endTime.flatMap { Configuration.iso8601DateFormatter.date(from: $0) },
            amount: amount,
            unit: unit.flatMap { PhysiologyLogUnit(rawValue: $0) },
            notes: notes
        )
    }
}

private struct ContextEventResponse: Decodable {
    let id: String
    let babyId: String
    let type: String?
    let title: String
    let startDate: String
    let endDate: String?
    let notes: String?

    func toContextEvent() -> ContextEvent {
        ContextEvent(
            id: id,
            babyId: babyId,
            type: type.flatMap { ContextEventType(rawValue: $0) },
            title: title,
            startDate: Configuration.dateOnlyFormatter.date(from: startDate) ?? Date(),
            endDate: endDate.flatMap { Configuration.dateOnlyFormatter.date(from: $0) },
            notes: notes
        )
    }
}

// MARK: - Errors

enum AmplifyServiceError: LocalizedError {
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
