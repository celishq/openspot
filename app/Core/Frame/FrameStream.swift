import Foundation

struct FrameStream: Sendable {
    let text: String
    let drawn: String?

    init(_ text: String, after drawn: String?, apart: Set<String> = []) {
        let blocks = TextBlock.blocks(in: text)
        guard !blocks.contains(where: { $0.value(RootKey.end).map(apart.contains) == true }) else {
            self.text = text
            self.drawn = drawn
            return
        }
        let drawing = blocks.filter(Self.draws)
        guard !drawing.isEmpty, let base = drawn, !blocks.contains(where: RootKey.starts) else {
            self.text = text
            self.drawn = drawing.isEmpty ? drawn : text
            return
        }
        let merged = TextBlock.patching(TextBlock.blocks(in: base).filter { RootKey.starts($0) || Self.draws($0) }, with: drawing) { block in
            RootKey.starts(block) ? nil : Self.id(of: block)
        }
        let whole = merged.map(\.text).joined(separator: "\n")
        self.text = ([whole] + blocks.filter { !RootKey.starts($0) && !Self.draws($0) }.map(\.text)).joined(separator: "\n")
        self.drawn = whole
    }

    @concurrent static func next(_ text: String, after drawn: String?, apart: Set<String> = []) async -> FrameStream {
        FrameStream(text, after: drawn, apart: apart)
    }

    private static func draws(_ block: TextBlock) -> Bool {
        guard let key = block.fields.first?.key else { return false }
        return key != RootKey.frame.rawValue && !RootKey.marks.contains(key)
    }

    private static func id(of block: TextBlock) -> String? {
        block.fields.first.flatMap { $0.value.isEmpty ? nil : $0.value }
    }
}
