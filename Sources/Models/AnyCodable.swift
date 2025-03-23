import Foundation

/// A type-erasing wrapper that allows any encodable/decodable value to be encoded/decoded
public struct AnyCodable: Codable, Equatable {
    /// The wrapped value
    public let value: Any
    
    /// String representation of the value, useful for debugging
    public var stringValue: String? {
        if let string = value as? String {
            return string
        } else if let data = try? JSONEncoder().encode(self),
                  let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
    
    /// Int representation if available
    public var intValue: Int? {
        return value as? Int
    }
    
    /// Double representation if available
    public var doubleValue: Double? {
        return value as? Double ?? (value as? Int).map(Double.init)
    }
    
    /// Bool representation if available
    public var boolValue: Bool? {
        return value as? Bool
    }
    
    /// Dictionary representation if available
    public var dictionaryValue: [String: AnyCodable]? {
        guard let dictionary = value as? [String: Any] else { return nil }
        return dictionary.mapValues(AnyCodable.init)
    }
    
    /// Array representation if available
    public var arrayValue: [AnyCodable]? {
        guard let array = value as? [Any] else { return nil }
        return array.map(AnyCodable.init)
    }
    
    /// Initialize with any value
    public init(_ value: Any) {
        self.value = value
    }
    
    /// Initialize from a decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = Optional<Any>.none as Any
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    /// Encode to an encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull, is Void:
            try container.encodeNil()
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
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case let codable as Encodable:
            try codable.encode(to: encoder)
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded: \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
    
    /// Compare two AnyCodable values for equality
    public static func ==(lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull), is (Void, Void):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        case let (lhs as [Any], rhs as [Any]):
            return (lhs.count == rhs.count) && 
                   zip(lhs, rhs).allSatisfy { AnyCodable($0) == AnyCodable($1) }
        case let (lhs as [String: Any], rhs as [String: Any]):
            return (lhs.count == rhs.count) &&
                   lhs.allSatisfy { key, value in
                       rhs[key].map { AnyCodable(value) == AnyCodable($0) } ?? false
                   }
        default:
            return false
        }
    }
}

// MARK: - ExpressibleBy... protocols

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.init(NSNull())
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = Dictionary<String, Any>(uniqueKeysWithValues: elements)
        self.init(dictionary)
    }
} 