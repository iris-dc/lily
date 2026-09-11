import Foundation

/// JSON conventions shared with the backend: field names as they are, instants as ISO-8601 in UTC. The backend
/// writes second precision (`2026-09-13T17:00:00Z`); reading also accepts fractional seconds from other producers.
nonisolated enum APIJSONCoding {
    private static let fractionalInstant = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let instant = Date.ISO8601FormatStyle()

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parseInstant(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO-8601 instant: \(text)")
            }
            return date
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Fractional first, so `.250` is kept when present; the plain style then covers the backend's own output.
    static func parseInstant(_ text: String) -> Date? {
        (try? fractionalInstant.parse(text)) ?? (try? instant.parse(text))
    }
}
