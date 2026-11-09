import Foundation

/// One text of a search index, as one folded code per character, with the offsets where its words begin. It reads the
/// buffers of the index in place, so it lives only during a search of that index.
struct FoldedText {
    let letters: UnsafeBufferPointer<UInt32>
    let starts: UnsafeBufferPointer<UInt32>

    /// Where a word lies in the text.
    enum Place {
        case wordStart
        case inside
    }

    /// Where the word lies: at the start of a word when it does anywhere, else inside a word, else nil.
    func place(of word: [UInt32]) -> Place? {
        guard let first = word.first, word.count <= letters.count else { return nil }
        var place: Place?
        var start = 0
        for offset in 0...(letters.count - word.count) where letters[offset] == first && holds(word, at: offset) {
            while start < starts.count, Int(starts[start]) < offset { start += 1 }
            if start < starts.count, Int(starts[start]) == offset { return .wordStart }
            place = .inside
        }
        return place
    }

    private func holds(_ word: [UInt32], at offset: Int) -> Bool {
        for index in 1..<word.count where letters[offset + index] != word[index] { return false }
        return true
    }

    /// Whether the letters at the word starts spell the word in order.
    func spellsAtWordStarts(_ word: [UInt32]) -> Bool {
        var next = 0
        for start in starts where next < word.count && letters[Int(start)] == word[next] { next += 1 }
        return next == word.count
    }

    /// Whether the letters of one word spell the word in order.
    func spellsInOneWord(_ word: [UInt32]) -> Bool {
        for index in starts.indices {
            let end = index + 1 < starts.count ? Int(starts[index + 1]) : letters.count
            var next = 0
            for offset in Int(starts[index])..<end where letters[offset] == word[next] {
                next += 1
                if next == word.count { return true }
            }
        }
        return false
    }

    /// The bit of a letter code in a set of letters: its value modulo 64.
    static func bit(of code: UInt32) -> UInt64 {
        1 << (UInt64(code) % 64)
    }

    /// The code of a character with no case and no accents: its scalar when it folds to one, or else a hash of its scalars,
    /// which has the top bit set, so that it differs from any scalar.
    static func code(_ character: Character) -> UInt32 {
        if let ascii = character.asciiValue { return UInt32(ascii >= 65 && ascii <= 90 ? ascii + 32 : ascii) }
        let scalars = String(character).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).unicodeScalars
        if scalars.count == 1, let scalar = scalars.first { return scalar.value }
        return UInt32(truncatingIfNeeded: scalars.reduce(0xcbf29ce484222325 as UInt64) { ($0 ^ UInt64($1.value)) &* 0x100000001b3 }) | 1 << 31
    }
}
