import Foundation

struct PhysiologyLog: Identifiable, Codable, Hashable {
    let id: String
    let babyId: String
    let familyOwners: [String]?
    let type: PhysiologyLogType?
    let startTime: Date
    let endTime: Date?
    let amount: Double?
    let unit: PhysiologyLogUnit?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String = UUID().uuidString,
        babyId: String,
        familyOwners: [String]? = nil,
        type: PhysiologyLogType? = nil,
        startTime: Date,
        endTime: Date? = nil,
        amount: Double? = nil,
        unit: PhysiologyLogUnit? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.babyId = babyId
        self.familyOwners = familyOwners
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.amount = amount
        self.unit = unit
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayDescription: String {
        guard let type = type else { return "Log" }

        var parts: [String] = [type.displayName]

        if let amount = amount, let unit = unit {
            let formattedAmount = amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", amount)
                : String(format: "%.1f", amount)
            parts.append("\(formattedAmount)\(unit.displayName)")
        }

        return parts.joined(separator: " - ")
    }

    var durationMinutes: Int? {
        guard let endTime = endTime else { return nil }
        let seconds = endTime.timeIntervalSince(startTime)
        return Int(seconds / 60)
    }

    var timeDisplayString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
}

// MARK: - Create DTO

struct CreatePhysiologyLogInput: Encodable {
    let babyId: String
    let familyOwners: [String]?
    let type: String?
    let startTime: String // ISO8601 datetime
    let endTime: String?
    let amount: Double?
    let unit: String?
    let notes: String?
}
