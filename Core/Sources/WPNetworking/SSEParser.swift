import Foundation

/// Incremental UTF-8 SSE framing. Blank lines dispatch; comments and other fields are ignored.
public struct SSEParser: Sendable {
    private var line: [UInt8] = []
    private var data: [String] = []
    private var afterCR = false
    public init() {}
    public mutating func consume(_ byte: UInt8) -> String? {
        if byte == 10 && afterCR { afterCR = false; return nil }
        afterCR = byte == 13
        if byte == 10 || byte == 13 {
            let text = String(decoding: line, as: UTF8.self); line.removeAll(keepingCapacity: true)
            if text.isEmpty {
                guard !data.isEmpty else { return nil }
                let result = data.joined(separator: "\n"); data.removeAll(keepingCapacity: true); return result
            }
            if text.hasPrefix("data:") {
                var value = String(text.dropFirst(5)); if value.first == " " { value.removeFirst() }; data.append(value)
            } else if text == "data" { data.append("") }
        } else { line.append(byte) }
        return nil
    }
}
