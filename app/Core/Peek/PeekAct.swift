import Foundation

public struct PeekAct: Equatable, Sendable {
    static let key = "action"

    let lines: [ActionLine]

    init?(block: TextBlock) {
        let texts = block.values(Self.key)
        let lines = texts.compactMap(ActionLine.init(text:))
        guard !lines.isEmpty, lines.count == texts.count else { return nil }
        self.lines = lines
    }

    static func actions(of blocks: [TextBlock]) -> [CommandAction] {
        let buttons = blocks.dropFirst().filter { $0.fields.first?.key == BlockKind.button.word }
        let names = buttons.compactMap { $0.fields.first?.value }
        return buttons.compactMap { block in
            guard let name = block.fields.first?.value, let title = block.value("title") else { return nil }
            if let act = PeekAct(block: block) { return .act(act, name: name, title: title) }
            guard block.values(key).isEmpty else { return nil }
            if names.contains(where: { $0.hasPrefix(name + ".") }) { return .group(name, title: title) }
            return CommandAction(id: name, title: title, scope: .item, after: .close)
        }
    }
}
