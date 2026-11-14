import Darwin

enum JSON {
    case object([String: JSON])
    case array([JSON])
    case text([UInt8])
    case number(Double)
    case other

    init?(_ bytes: [UInt8]) {
        var place = 0
        guard let value = Self.value(bytes, &place) else { return nil }
        self = value
    }

    subscript(key: String) -> JSON? {
        if case .object(let fields) = self { return fields[key] }
        return nil
    }

    static func quoted(_ text: String) -> String {
        var quoted = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": quoted += "\\\""
            case "\\": quoted += "\\\\"
            case "\n": quoted += "\\n"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                quoted += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: quoted.unicodeScalars.append(scalar)
            }
        }
        return quoted + "\""
    }

    private static func value(_ bytes: [UInt8], _ place: inout Int) -> JSON? {
        skipSpace(bytes, &place)
        guard place < bytes.count else { return nil }
        switch bytes[place] {
        case UInt8(ascii: "{"):
            place += 1
            var fields: [String: JSON] = [:]
            skipSpace(bytes, &place)
            if place < bytes.count, bytes[place] == UInt8(ascii: "}") {
                place += 1
                return .object(fields)
            }
            while true {
                skipSpace(bytes, &place)
                guard case .text(let key)? = value(bytes, &place) else { return nil }
                skipSpace(bytes, &place)
                guard place < bytes.count, bytes[place] == UInt8(ascii: ":") else { return nil }
                place += 1
                guard let field = value(bytes, &place) else { return nil }
                fields[String(decoding: key, as: UTF8.self)] = field
                skipSpace(bytes, &place)
                guard place < bytes.count else { return nil }
                place += 1
                if bytes[place - 1] == UInt8(ascii: "}") { return .object(fields) }
                guard bytes[place - 1] == UInt8(ascii: ",") else { return nil }
            }
        case UInt8(ascii: "["):
            place += 1
            var items: [JSON] = []
            skipSpace(bytes, &place)
            if place < bytes.count, bytes[place] == UInt8(ascii: "]") {
                place += 1
                return .array(items)
            }
            while true {
                guard let item = value(bytes, &place) else { return nil }
                items.append(item)
                skipSpace(bytes, &place)
                guard place < bytes.count else { return nil }
                place += 1
                if bytes[place - 1] == UInt8(ascii: "]") { return .array(items) }
                guard bytes[place - 1] == UInt8(ascii: ",") else { return nil }
            }
        case UInt8(ascii: "\""):
            return text(bytes, &place).map(JSON.text)
        default:
            let start = place
            while place < bytes.count, !",}] \n\r\t".utf8.contains(bytes[place]) { place += 1 }
            let word = String(decoding: bytes[start..<place], as: UTF8.self)
            guard !word.isEmpty else { return nil }
            return Double(word).map(JSON.number) ?? (["true", "false", "null"].contains(word) ? .other : nil)
        }
    }

    private static func text(_ bytes: [UInt8], _ place: inout Int) -> [UInt8]? {
        place += 1
        var text: [UInt8] = []
        var high: UInt32?
        while place < bytes.count {
            let byte = bytes[place]
            place += 1
            if byte == UInt8(ascii: "\"") { return text }
            guard byte == UInt8(ascii: "\\") else {
                text.append(byte)
                continue
            }
            guard place < bytes.count else { return nil }
            let mark = bytes[place]
            place += 1
            switch mark {
            case UInt8(ascii: "b"): text.append(0x08)
            case UInt8(ascii: "f"): text.append(0x0C)
            case UInt8(ascii: "n"): text.append(0x0A)
            case UInt8(ascii: "r"): text.append(0x0D)
            case UInt8(ascii: "t"): text.append(0x09)
            case UInt8(ascii: "u"):
                guard place + 4 <= bytes.count, let code = UInt32(String(decoding: bytes[place..<place + 4], as: UTF8.self), radix: 16) else { return nil }
                place += 4
                if (0xD800...0xDBFF).contains(code) {
                    high = code
                    continue
                }
                let value = high.flatMap { (0xDC00...0xDFFF).contains(code) ? 0x10000 + (($0 - 0xD800) << 10) + (code - 0xDC00) : nil } ?? code
                high = nil
                text += Array(String(Unicode.Scalar(value).map(Character.init) ?? "\u{FFFD}").utf8)
            default: text.append(mark)
            }
        }
        return nil
    }

    private static func skipSpace(_ bytes: [UInt8], _ place: inout Int) {
        while place < bytes.count, " \n\r\t".utf8.contains(bytes[place]) { place += 1 }
    }
}
