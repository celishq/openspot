import Foundation

/// The bech32 text of NIP-19, such as an `npub` or an `nsec`: a prefix, the bytes in 5-bit groups, and a checksum.
enum Bech32 {
    private static let alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    private static let generator: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]

    /// The text of these bytes under a prefix.
    static func encode(_ prefix: String, _ bytes: Data) -> String {
        let values = regroup(Array(bytes), from: 8, to: 5, pads: true) ?? []
        let check = checksum(prefix, values)
        return prefix + "1" + String((values + check).map { alphabet[Int($0)] })
    }

    /// The bytes of a text with this prefix, or nil when the prefix, a letter or the checksum is wrong.
    static func decode(_ text: String, prefix: String) -> Data? {
        let lower = text.lowercased()
        guard lower == text || text.uppercased() == text, let split = lower.lastIndex(of: "1"),
              String(lower[..<split]) == prefix else { return nil }
        var values: [UInt8] = []
        for letter in lower[lower.index(after: split)...] {
            guard let index = alphabet.firstIndex(of: letter) else { return nil }
            values.append(UInt8(index))
        }
        guard values.count >= 6, polymod(expanded(prefix) + values) == 1 else { return nil }
        return regroup(Array(values.dropLast(6)), from: 5, to: 8, pads: false).map { Data($0) }
    }

    private static func checksum(_ prefix: String, _ values: [UInt8]) -> [UInt8] {
        let mod = polymod(expanded(prefix) + values + [0, 0, 0, 0, 0, 0]) ^ 1
        return (0..<6).map { UInt8((mod >> (5 * (5 - UInt32($0)))) & 31) }
    }

    private static func expanded(_ prefix: String) -> [UInt8] {
        let bytes = Array(prefix.utf8)
        return bytes.map { $0 >> 5 } + [0] + bytes.map { $0 & 31 }
    }

    private static func polymod(_ values: [UInt8]) -> UInt32 {
        var check: UInt32 = 1
        for value in values {
            let top = check >> 25
            check = (check & 0x1ffffff) << 5 ^ UInt32(value)
            for (bit, factor) in generator.enumerated() where (top >> UInt32(bit)) & 1 == 1 { check ^= factor }
        }
        return check
    }

    private static func regroup(_ values: [UInt8], from: Int, to: Int, pads: Bool) -> [UInt8]? {
        var accumulator = 0
        var bits = 0
        var result: [UInt8] = []
        let mask = (1 << to) - 1
        for value in values {
            guard Int(value) >> from == 0 else { return nil }
            accumulator = (accumulator << from) | Int(value)
            bits += from
            while bits >= to {
                bits -= to
                result.append(UInt8((accumulator >> bits) & mask))
            }
        }
        if pads, bits > 0 { result.append(UInt8((accumulator << (to - bits)) & mask)) }
        if !pads, bits >= from || (accumulator << (to - bits)) & mask != 0 { return nil }
        return result
    }
}
