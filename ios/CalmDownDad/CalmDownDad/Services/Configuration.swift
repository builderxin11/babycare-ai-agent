import Foundation

enum Configuration {
    // MARK: - API Configuration

    #if DEBUG
    static let agentAPIBaseURL = URL(string: "http://localhost:8000")!
    #else
    static let agentAPIBaseURL = URL(string: "https://api.nurturemind.app")!
    #endif

    // MARK: - API Endpoints

    enum Endpoints {
        static let ask = "/ask"
        static let report = "/report"
        static let health = "/health"
        static let babies = "/babies"
        static let logs = "/logs"
        static let events = "/events"
    }

    // MARK: - Timeouts

    static let requestTimeout: TimeInterval = 60.0 // Agent calls can take a while
    static let resourceTimeout: TimeInterval = 120.0

    // MARK: - Date Formatters

    static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601DateOnlyFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - JSON Decoder

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with time
            if let date = iso8601DateFormatter.date(from: dateString) {
                return date
            }

            // Try date only
            if let date = dateOnlyFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        return decoder
    }()

    // MARK: - JSON Encoder

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = iso8601DateFormatter.string(from: date)
            try container.encode(dateString)
        }
        return encoder
    }()
}
