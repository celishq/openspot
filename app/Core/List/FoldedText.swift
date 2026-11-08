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

    func occurrences(of word: [UInt64]) -> [Int] {
        guard !word.isEmpty, word.count <= letters.count else { return [] }
        return (0...(letters.count - word.count)).filter { letters[$0..<$0 + word.count].elementsEqual(word) }
    }

    /// The offsets of the first word whose letters spell the word in order.
    func inOneWord(_ word: [UInt64]) -> [Int]? {
        zip(starts, starts.dropFirst() + [letters.count]).lazy.compactMap { inOrder(word, among: Array($0..<$1)) }.first
    }

    /// The first offsets among the given ones whose letters spell the word in order.
    func inOrder(_ word: [UInt64], among offsets: [Int]) -> [Int]? {
        var found: [Int] = []
        var rest = offsets[...]
        for letter in word {
            guard let index = rest.firstIndex(where: { letters[$0] == letter }) else { return nil }
            found.append(rest[index])
            rest = rest[(index + 1)...]
        }
        return found
    }

    /// The code of a character with no case and no accents: its scalar when it folds to one, or else a hash of its scalars.
    static func code(_ character: Character) -> UInt64 {
        if let ascii = character.asciiValue { return UInt64(ascii >= 65 && ascii <= 90 ? ascii + 32 : ascii) }
        let scalars = String(character).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).unicodeScalars
        if scalars.count == 1, let scalar = scalars.first { return UInt64(scalar.value) }
        return scalars.reduce(0xcbf29ce484222325 as UInt64) { ($0 ^ UInt64($1.value)) &* 0x100000001b3 } | 1 << 63
    }
}
