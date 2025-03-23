import Foundation

/// A type-erasing wrapper for Codable values
public struct AnyCodable: Codable, Equatable {
    // MARK: - Properties
    
    private let value: Any
    
    // MARK: - Computed Properties
    
    /// Attempt to get the value as a String
    public var stringValue: String? {
        return value as? String
    }
    
    /// Attempt to get the value as an Int
    public var intValue: Int? {
        return value as? Int
    }
    
    /// Attempt to get the value as a Double
    public var doubleValue: Double? {
        return value as? Double ?? (value as? Int).map(Double.init)
    }
    
    /// Attempt to get the value as a Bool
    public var boolValue: Bool? {
        return value as? Bool
    }
    
    /// Attempt to get the value as a Dictionary
    public var dictionaryValue: [String: AnyCodable]? {
        return value as? [String: AnyCodable]
    }
    
    /// Attempt to get the value as an Array
    public var arrayValue: [AnyCodable]? {
        return value as? [AnyCodable]
    }
    
    // MARK: - Initialization
    
    /// Initialize with a value
    public init(_ value: Any) {
        self.value = value
    }
    
    // MARK: - Codable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [AnyCodable]:
            try container.encode(array)
        case let dictionary as [String: AnyCodable]:
            try container.encode(dictionary)
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded: \(value)"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (lhsValue as Bool, rhsValue as Bool):
            return lhsValue == rhsValue
        case let (lhsValue as Int, rhsValue as Int):
            return lhsValue == rhsValue
        case let (lhsValue as Double, rhsValue as Double):
            return lhsValue == rhsValue
        case let (lhsValue as String, rhsValue as String):
            return lhsValue == rhsValue
        case let (lhsValue as [String: AnyCodable], rhsValue as [String: AnyCodable]):
            return lhsValue == rhsValue
        case let (lhsValue as [AnyCodable], rhsValue as [AnyCodable]):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

// MARK: - ExpressibleBy Protocols

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.value = NSNull()
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: AnyCodable...) {
        self.value = elements
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, AnyCodable)...) {
        var dictionary = [String: AnyCodable]()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self.value = dictionary
    }
} 