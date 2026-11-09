import Foundation

/// The searched texts of the items of one list, folded once: every letter in one buffer and a small record for each item,
/// so that a search reads memory in order. It holds no item; the list keeps its items beside it, in the same order.
struct SearchIndex: Equatable, Sendable {
    /// Where one text lies: its letters, and the offsets of its word starts from its first letter.
    fileprivate struct Span: Equatable, Sendable {
        let letters: Range<UInt32>
        let starts: Range<UInt32>
    }

    /// One item: its texts, which are its title, then its subtitle when it has one, then its keywords.
    fileprivate struct Record: Equatable, Sendable {
        let texts: Range<UInt32>
        let hasSubtitle: Bool
        let glyph: String?
        let letterBits: UInt64
    }

    private var letters: [UInt32] = []
    private var starts: [UInt32] = []
    private var spans: [Span] = []
    private var records: [Record] = []

    init(_ items: [SpotItem] = []) {
        records.reserveCapacity(items.count)
        for item in items {
            let first = UInt32(spans.count)
            var bits = append(item.title)
            if let subtitle = item.subtitle { bits |= append(subtitle) }
            for keyword in item.keywords { bits |= append(keyword) }
            records.append(Record(texts: first..<UInt32(spans.count), hasSubtitle: item.subtitle != nil, glyph: item.glyph.map(FoldedItem.plain), letterBits: bits))
        }
    }

    var count: Int {
        records.count
    }

    /// Folds a text onto the buffers, and returns one bit for each of its letters. A word begins after a character that is
    /// not a letter or a digit, or at a capital after a small letter. Plain ASCII text takes a path that reads its bytes.
    private mutating func append(_ text: String) -> UInt64 {
        let first = letters.count
        let firstStart = starts.count
        var bits: UInt64 = 0
        if text.utf8.allSatisfy({ $0 < 128 && $0 != 13 }) {
            var previous: UInt8 = 32
            for byte in text.utf8 {
                if Self.isWord(byte), !Self.isWord(previous) || (Self.isCapital(byte) && Self.isSmall(previous)) {
                    starts.append(UInt32(letters.count - first))
                }
                let code = UInt32(Self.isCapital(byte) ? byte + 32 : byte)
                letters.append(code)
                bits |= FoldedText.bit(of: code)
                previous = byte
            }
        } else {
            var previous: Character?
            for character in text {
                if character.isLetter || character.isNumber,
                   previous.map({ !($0.isLetter || $0.isNumber) || (character.isUppercase && $0.isLowercase) }) ?? true {
                    starts.append(UInt32(letters.count - first))
                }
                let code = FoldedText.code(character)
                letters.append(code)
                bits |= FoldedText.bit(of: code)
                previous = character
            }
        }
        spans.append(Span(letters: UInt32(first)..<UInt32(letters.count), starts: UInt32(firstStart)..<UInt32(starts.count)))
        return bits
    }

    private static func isWord(_ byte: UInt8) -> Bool {
        isCapital(byte) || isSmall(byte) || (48...57).contains(byte)
    }

    private static func isCapital(_ byte: UInt8) -> Bool {
        (65...90).contains(byte)
    }

    private static func isSmall(_ byte: UInt8) -> Bool {
        (97...122).contains(byte)
    }

    /// Calls `body` with the items, which read the buffers in place and live only during the call.
    func withItems<Result>(_ body: (Items) -> Result) -> Result {
        letters.withUnsafeBufferPointer { letters in
            starts.withUnsafeBufferPointer { starts in
                spans.withUnsafeBufferPointer { spans in
                    records.withUnsafeBufferPointer { records in
                        body(Items(letters: letters, starts: starts, spans: spans, records: records))
                    }
                }
            }
        }
    }

    /// The items of an index, read in place.
    struct Items {
        fileprivate let letters: UnsafeBufferPointer<UInt32>
        fileprivate let starts: UnsafeBufferPointer<UInt32>
        fileprivate let spans: UnsafeBufferPointer<Span>
        fileprivate let records: UnsafeBufferPointer<Record>

        subscript(index: Int) -> FoldedItem {
            let record = records[index]
            let first = Int(record.texts.lowerBound)
            return FoldedItem(
                title: text(first),
                subtitle: record.hasSubtitle ? text(first + 1) : nil,
                keywords: Texts(items: self, range: (first + (record.hasSubtitle ? 2 : 1))..<Int(record.texts.upperBound)),
                glyph: record.glyph,
                letterBits: record.letterBits
            )
        }

        fileprivate func text(_ index: Int) -> FoldedText {
            let span = spans[index]
            return FoldedText(
                letters: UnsafeBufferPointer(rebasing: letters[Int(span.letters.lowerBound)..<Int(span.letters.upperBound)]),
                starts: UnsafeBufferPointer(rebasing: starts[Int(span.starts.lowerBound)..<Int(span.starts.upperBound)])
            )
        }
    }

    /// Some texts of an index, such as the keywords of one item, read in place.
    struct Texts: RandomAccessCollection {
        fileprivate let items: Items
        fileprivate let range: Range<Int>

        var startIndex: Int {
            range.lowerBound
        }

        var endIndex: Int {
            range.upperBound
        }

        subscript(position: Int) -> FoldedText {
            items.text(position)
        }
    }
}
