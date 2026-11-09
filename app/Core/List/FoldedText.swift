import Foundation

/// Text as one folded code per character, with the offsets where its words begin.
struct FoldedText: Equatable, Sendable {
    let letters: [UInt64]
    let starts: [Int]

    /// A word begins after a character that is not a letter or a digit, or at a capital after a small letter.
    init(_ text: String) {
        let characters = Array(text)
        letters = characters.map(Self.code)
        starts = characters.indices.filter { index in
            let character = characters[index]
            guard character.isLetter || character.isNumber else { return false }
            guard index > 0 else { return true }
            let previous = characters[index - 1]
            return !(previous.isLetter || previous.isNumber) || (character.isUppercase && previous.isLowercase)
        }
    }

    /// Where a word lies in the text.
    enum Place {
        case wordStart
        case inside
    }

    /// Where the word lies: at the start of a word when it does anywhere, else inside a word, else nil.
    func place(of word: [UInt64]) -> Place? {
        guard let first = word.first, word.count <= letters.count else { return nil }
        var place: Place?
        var start = starts.startIndex
        for offset in 0...(letters.count - word.count) where letters[offset] == first && letters[offset..<offset + word.count].elementsEqual(word) {
            while start < starts.endIndex, starts[start] < offset { start += 1 }
            if start < starts.endIndex, starts[start] == offset { return .wordStart }
            place = .inside
        }
        return place
    }

    /// Whether the letters of one word spell the word in order.
    func spellsInOneWord(_ word: [UInt64]) -> Bool {
        starts.indices.contains { index in
            spells(word, inOrderAmong: starts[index]..<(index + 1 < starts.count ? starts[index + 1] : letters.count))
        }
    }

    /// Whether the letters at the given offsets spell the word in order.
    func spells<Offsets: Collection<Int>>(_ word: [UInt64], inOrderAmong offsets: Offsets) -> Bool {
        var rest = offsets[...]
        for letter in word {
            guard let index = rest.firstIndex(where: { letters[$0] == letter }) else { return false }
            rest = rest[rest.index(after: index)...]
        }
        return true
    }

    /// One bit for each letter code, by its value modulo 64.
    static func bits(of letters: [UInt64]) -> UInt64 {
        letters.reduce(0) { $0 | 1 << ($1 % 64) }
    }

    /// The code of a character with no case and no accents: its scalar when it folds to one, or else a hash of its scalars.
    static func code(_ character: Character) -> UInt64 {
        if let ascii = character.asciiValue { return UInt64(ascii >= 65 && ascii <= 90 ? ascii + 32 : ascii) }
        let scalars = String(character).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).unicodeScalars
        if scalars.count == 1, let scalar = scalars.first { return UInt64(scalar.value) }
        return scalars.reduce(0xcbf29ce484222325 as UInt64) { ($0 ^ UInt64($1.value)) &* 0x100000001b3 } | 1 << 63
    }
}
