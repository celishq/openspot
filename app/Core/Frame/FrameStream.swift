import Foundation

struct FrameStream: Sendable {
    let text: String
    let drawn: String?

    init(_ text: String, after drawn: String?) {
        let blocks = TextBlock.blocks(in: text)
        let drawing = blocks.filter(Self.draws)
        guard !drawing.isEmpty, let base = drawn, !blocks.contains(where: RootKey.starts) else {
            self.text = text
            self.drawn = drawing.isEmpty ? drawn : text
            return
        }
        var merged = TextBlock.blocks(in: base).filter { RootKey.starts($0) || Self.draws($0) }
        for block in drawing {
            if let id = Self.id(of: block), let index = merged.firstIndex(where: { !RootKey.starts($0) && Self.id(of: $0) == id }) {
                merged[index] = block
            } else {
                merged.append(block)
            }
        }
        let whole = merged.map(\.text).joined(separator: "\n")
        self.text = ([whole] + blocks.filter { !RootKey.starts($0) && !Self.draws($0) }.map(\.text)).joined(separator: "\n")
        self.drawn = whole
    }

    @concurrent static func next(_ text: String, after drawn: String?) async -> FrameStream {
        FrameStream(text, after: drawn)
    }

    private static func draws(_ block: TextBlock) -> Bool {
        guard let key = block.fields.first?.key else { return false }
        return key != RootKey.frame.rawValue && !RootKey.marks.contains(key)
    }

    private static func id(of block: TextBlock) -> String? {
        block.fields.first.flatMap { $0.value.isEmpty ? nil : $0.value }
    }
}
