import CoreGraphics
import Foundation

extension ViewTree {
    private static let letterWidth: CGFloat = 6.5
    private static let detailLetterWidth: CGFloat = 5.5
    private static let controlWidth: CGFloat = 52
    private static let smallSwatchWidth: CGFloat = 18

    func sheetFaults(parts: [SpotPart]) -> [String] {
        var faults = parts.filter { $0.look == .strong }.count > 1 ? ["only one part can use look=strong"] : []
        var words = Dictionary(parts.compactMap { part in Self.wordsWidth(of: part, isText: nodes[part.id]?.kind == BlockKind.text.word).map { (part.id, $0) } }) { first, _ in first }
        for node in nodes.values where node.kind == BlockKind.icon.word { words[node.id] = SpotTokens.listIconSize }
        let frames = frames(in: SpotTokens.partsWidth, room: SpotTokens.partsMaxHeight, parts: parts, words: words)
        for id in shown(in: [.sheet]) {
            guard let node = nodes[id], let frame = frames[id] else { continue }
            let style = node.style.resolved(for: [.sheet])
            if node.kind == BlockKind.text.word, frame.height < leafHeight(node, style, lines: 1, width: frame.width) - 0.5 {
                faults.append("the text \(id) is \(Int(frame.height))pt tall, so its words are cut. Give it more room")
            }
            guard let part = parts.first(where: { $0.id == id }), let width = words[id], !part.fillsHeight,
                  node.kind != BlockKind.text.word || style.truncates else { continue }
            if width > frame.width + 0.5 { faults.append("the title of the part \(id) may not fit its cell") }
        }
        return faults
    }

    private static func wordsWidth(of part: SpotPart, isText: Bool) -> CGFloat? {
        guard let title = part.title else { return nil }
        if isText { return max(CGFloat(title.count) * letterWidth, CGFloat(part.detail?.count ?? 0) * detailLetterWidth) }
        var control = part.control == .none && part.press != .line ? 0 : controlWidth
        if case .swatches = part.control { control = smallSwatchWidth }
        let detail = part.detail.map { CGFloat($0.count) * detailLetterWidth + 2 * SpotTokens.partGap } ?? 0
        return CGFloat(title.count) * letterWidth + detail + (part.press == .line ? 0 : control)
    }
}
