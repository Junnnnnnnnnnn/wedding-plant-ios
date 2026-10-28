import Foundation

/// 숫자가 JSON에서 `Int` / `Double` / `String` 중 무엇으로 와도 받아내는 디코더.
///
/// 웹 코드가 `budget?: number | string | null` 로 선언되어 있어(`lib/api.ts:isPlanDataComplete`)
/// 백엔드가 문자열 숫자를 보내는 경우가 실제로 존재한다. Swift에서 타입 불일치로 전체 디코딩이
/// 실패하는 사고를 막기 위한 래퍼.
@propertyWrapper
public struct LooseInt: Codable, Hashable, Sendable {
    public var wrappedValue: Int?

    public init(wrappedValue: Int?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.wrappedValue = nil
        } else if let intValue = try? container.decode(Int.self) {
            self.wrappedValue = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.wrappedValue = Int(doubleValue.rounded())
        } else if let stringValue = try? container.decode(String.self) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespaces)
            self.wrappedValue = Int(trimmed) ?? Double(trimmed).map { Int($0.rounded()) }
        } else {
            self.wrappedValue = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let wrappedValue {
            try container.encode(wrappedValue)
        } else {
            try container.encodeNil()
        }
    }
}

extension KeyedDecodingContainer {
    /// 키 자체가 없을 때도 `nil` 로 처리되도록 하는 오버로드.
    /// (`@LooseInt` 프로퍼티는 optional 이므로 키 누락을 허용해야 한다.)
    public func decode(_ type: LooseInt.Type, forKey key: Key) throws -> LooseInt {
        try decodeIfPresent(LooseInt.self, forKey: key) ?? LooseInt(wrappedValue: nil)
    }
}

// Monetary values must preserve fractional ten-thousand-won units.
@propertyWrapper
/// 숫자를 문자열로 줘도(`"0.00000000"`) 읽는다 — Android 는 kotlinx `isLenient` 라 받는데 iOS 는 Double 로만 읽어, 운영 서버가
/// 일정 상세의 `locationLat`·`locationLng` 를 문자열로 주자 **일정 상세가 통째로 열리지 않았다**(2026-10-28 iOS QA DET-01).
/// 서버에서 오는 숫자(금액 · 좌표)는 이것으로 읽는다.
public struct LooseDouble: Codable, Hashable, Sendable {
    public var wrappedValue: Double?

    public init(wrappedValue: Double?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.wrappedValue = nil
        } else if let intValue = try? container.decode(Int.self) {
            self.wrappedValue = Double(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.wrappedValue = doubleValue.isFinite ? doubleValue : nil
        } else if let stringValue = try? container.decode(String.self) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespaces)
            self.wrappedValue = Double(trimmed).flatMap { $0.isFinite ? $0 : nil }
        } else {
            self.wrappedValue = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let wrappedValue {
            try container.encode(wrappedValue)
        } else {
            try container.encodeNil()
        }
    }
}

extension KeyedDecodingContainer {
    /// 키 자체가 없을 때도 `nil` 로 처리되도록 하는 오버로드.
    /// (`@LooseDouble` 프로퍼티는 optional 이므로 키 누락을 허용해야 한다.)
    public func decode(_ type: LooseDouble.Type, forKey key: Key) throws -> LooseDouble {
        try decodeIfPresent(LooseDouble.self, forKey: key) ?? LooseDouble(wrappedValue: nil)
    }
}
