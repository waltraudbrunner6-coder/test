import Foundation

/// UTC display + exact IEEE-754 reference seconds: Date roundtrips without millisecond truncation.
public enum PortableJSON {
    private struct Instant: Codable {
        let utc: String
        let referenceSeconds: Double
    }
    static func utc(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            guard date.timeIntervalSinceReferenceDate.isFinite else { throw EditorialPackageError.invalidJSON }
            try Instant(utc: utc(date), referenceSeconds: date.timeIntervalSinceReferenceDate).encode(to: encoder)
        }
        do { return try encoder.encode(value) }
        catch { throw EditorialPackageError.invalidJSON }
    }
    public static func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let instant = try Instant(from: decoder)
            guard instant.referenceSeconds.isFinite else { throw EditorialPackageError.invalidJSON }
            let date = Date(timeIntervalSinceReferenceDate: instant.referenceSeconds)
            guard instant.utc == utc(date) else { throw EditorialPackageError.invalidJSON }
            return date
        }
        do {
            let value = try decoder.decode(type, from: data)
            // Reject ignored unknown fields/noncanonical enum shapes. Whitespace/key ordering is immaterial.
            let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary
            let reconstructed = try JSONSerialization.jsonObject(with: encode(value)) as? NSDictionary
            guard let original, let reconstructed, original.isEqual(reconstructed) else { throw EditorialPackageError.invalidJSON }
            return value
        } catch { throw EditorialPackageError.invalidJSON }
    }
}
