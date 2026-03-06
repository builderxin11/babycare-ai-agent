import Foundation

struct GrowthMeasurement: Identifiable, Codable, Hashable {
    let id: String
    let babyId: String
    let type: GrowthMeasurementType
    let value: Double
    let measuredAt: Date
    let notes: String?

    init(
        id: String = UUID().uuidString,
        babyId: String,
        type: GrowthMeasurementType,
        value: Double,
        measuredAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.babyId = babyId
        self.type = type
        self.value = value
        self.measuredAt = measuredAt
        self.notes = notes
    }

    var displayValue: String {
        switch type {
        case .weight:
            return String(format: "%.1f %@", value, type.unit)
        case .height, .headCircumference:
            return String(format: "%.1f %@", value, type.unit)
        }
    }
}
