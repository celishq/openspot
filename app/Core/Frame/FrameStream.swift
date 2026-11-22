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
        let kept = Frame.grouping(TextBlock.blocks(in: base).filter { RootKey.starts($0) || Self.draws($0) })
        let grouped = Frame.grouping(drawing)
        var merged = TextBlock.patching(kept, with: grouped.filter { !Self.isOption($0) }) { block in
            RootKey.starts(block) ? nil : Self.id(of: block)
        }
        for option in grouped where Self.isOption(option) {
            let id = option.fields.first?.value
            if let index = merged.firstIndex(where: { $0.children.contains { $0.fields.first?.value == id } }) {
                merged[index] = merged[index].replacing(child: option)
            } else {
                merged.append(option)
            }
        }
        let whole = merged.map { ([$0] + $0.children).map(\.text).joined(separator: "\n") }.joined(separator: "\n")
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
        block.fields.first.flatMap { $0.value.isEmpty || $0.key == BlockKind.option ? nil : $0.value }
    }

    private static func isOption(_ block: TextBlock) -> Bool {
        block.fields.first?.key == BlockKind.option
    }
}
