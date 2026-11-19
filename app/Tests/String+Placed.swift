import Foundation
@testable import OpenspotCore

extension String {
    var placed: String {
        let blocks = TextBlock.blocks(in: self)
        let root = blocks.first { $0.fields.first?.key == RootKey.frame.rawValue }
        guard root?.value(RootKey.grid) == nil else { return self }
        let ids = blocks.compactMap { block -> String? in
            guard let key = block.fields.first?.key, BlockKind.all.contains(where: { $0.word == key }), key != BlockKind.button.word else { return nil }
            return block.fields.first?.value
        }
        guard !ids.isEmpty else { return self }
        let grid = ids.map { "grid=\($0)\n" }.joined()
        guard root != nil, let range = range(of: "frame=") else { return "frame=\n\(grid)\n" + self }
        let line = self[range.lowerBound...].firstIndex(of: "\n").map { index(after: $0) } ?? endIndex
        return String(self[..<line]) + (line == endIndex ? "\n" : "") + grid + self[line...]
    }
}
