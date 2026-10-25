import Foundation

/// Decodes to `nil` instead of throwing, so one malformed element can't fail a whole array.
struct Lossy<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

extension KeyedDecodingContainer {
    /// The value for `key`, or `nil` when it's missing, null or the wrong type.
    func lenient<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }

    /// Trimmed text for `key`, or `nil` when it's missing, blank or not a string.
    func text(forKey key: Key) -> String? {
        lenient(String.self, forKey: key)?.trimmed.nonEmpty
    }

    /// A number for `key`, accepting integers, decimals and numeric strings.
    func number(forKey key: Key) -> Double? {
        lenient(Double.self, forKey: key) ?? text(forKey: key).flatMap(Double.init)
    }

    /// `number(forKey:)` rounded to an integer; `nil` if it doesn't fit.
    func integer(forKey key: Key) -> Int? {
        number(forKey: key).flatMap { Int(exactly: $0.rounded()) }
    }
}

extension KeyedDecodingContainer {
    /// The value for `key`, or `fallback` when it's missing or null. Saved models decode every
    /// field this way, so adding or removing a field never invalidates saved data.
    func decode<T: Decodable>(_ key: Key, or fallback: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? fallback
    }
}
