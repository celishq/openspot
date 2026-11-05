import Foundation

/// The items a command prints, one block each. Each `run` value appears once.
public struct ItemBlocks: Equatable, Sendable {
    public private(set) var items: [SpotItem] = []
    public private(set) var errors: [String] = []

    public init(output: String) {
        var runs = Set<String>()
        for block in TextBlock.blocks(in: output) {
            if let item = SpotItem(block: block) {
                if runs.insert(item.run).inserted { items.append(item) }
            } else {
                errors.append(block.firstLine)
            }
        }
    }
}
