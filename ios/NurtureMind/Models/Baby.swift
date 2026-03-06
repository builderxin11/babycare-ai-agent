import Foundation

struct Baby: Identifiable, Codable, Hashable {
    let id: String
    let familyId: String
    let name: String
    let birthDate: Date
    let gender: BabyGender?
    let notes: String?
    let familyOwners: [String]?
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String = UUID().uuidString,
        familyId: String,
        name: String,
        birthDate: Date,
        gender: BabyGender? = nil,
        notes: String? = nil,
        familyOwners: [String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.notes = notes
        self.familyOwners = familyOwners
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var ageInMonths: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: Date())
        return components.month ?? 0
    }

    var ageInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: birthDate, to: Date())
        return components.day ?? 0
    }

    var ageDisplayString: String {
        let months = ageInMonths
        if months < 1 {
            let days = ageInDays
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if months < 24 {
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = months / 12
            let remainingMonths = months % 12
            if remainingMonths == 0 {
                return "\(years) year\(years == 1 ? "" : "s")"
            } else {
                return "\(years)y \(remainingMonths)m"
            }
        }
    }
}

// MARK: - Create/Update DTOs

struct CreateBabyInput: Encodable {
    let familyId: String
    let name: String
    let birthDate: String // ISO date format YYYY-MM-DD
    let gender: String?
    let notes: String?
    let familyOwners: [String]?
}

struct UpdateBabyInput: Encodable {
    let id: String
    let name: String?
    let birthDate: String?
    let gender: String?
    let notes: String?
}
