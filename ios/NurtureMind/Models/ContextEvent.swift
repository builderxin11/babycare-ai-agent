import Foundation
import Combine

struct ContextEvent: Identifiable, Codable, Hashable {
    let id: String
    let babyId: String
    let familyOwners: [String]?
    let type: ContextEventType?
    let title: String
    let startDate: Date
    let endDate: Date?
    let metadata: [String: AnyCodable]?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String = UUID().uuidString,
        babyId: String,
        familyOwners: [String]? = nil,
        type: ContextEventType? = nil,
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        metadata: [String: AnyCodable]? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.babyId = babyId
        self.familyOwners = familyOwners
        self.type = type
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.metadata = metadata
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var dateRangeDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let startStr = formatter.string(from: startDate)

        if let endDate = endDate {
            let endStr = formatter.string(from: endDate)
            return "\(startStr) - \(endStr)"
        }

        return startStr
    }

    var isOngoing: Bool {
        guard let endDate = endDate else { return true }
        return Date() < endDate
    }
}

// MARK: - Create DTO

struct CreateContextEventInput: Encodable {
    let babyId: String
    let familyOwners: [String]?
    let type: String?
    let title: String
    let startDate: String
    let endDate: String?
    let metadata: [String: AnyCodable]?
    let notes: String?
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
