import Foundation

struct KeySeed {
    private var state: UInt32

    init(_ text: String) {
        var hash: UInt32 = 2_166_136_261
        for unit in text.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 16_777_619
        }
        state = hash
    }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return Double(state % 10_000) / 10_000
    }

    mutating func pick(_ count: Int) -> Int {
        Int(next() * Double(count))
    }
}
