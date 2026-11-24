import Foundation
@testable import OpenspotCore

extension String {
    var placed: String {
        let blocks = TextBlock.blocks(in: self)
        let root = blocks.first { $0.fields.first?.key == RootKey.frame.rawValue }
        guard root?.value(ViewNode.classKey) == nil else { return self }
        let hasPart = blocks.contains { block in
            guard let key = block.fields.first?.key else { return false }
            return key != BlockKind.button.word && BlockKind.all.contains { $0.word == key }
        }
        guard hasPart else { return self }
        guard root != nil, let range = range(of: "frame=") else { return "frame=\nclass=gap-part\n\n" + self }
        let line = self[range.lowerBound...].firstIndex(of: "\n").map { index(after: $0) } ?? endIndex
        return String(self[..<line]) + (line == endIndex ? "\n" : "") + "class=gap-part\n" + self[line...]
    }
}
