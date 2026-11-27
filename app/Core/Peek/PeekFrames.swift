import Foundation

struct PeekFrames {
    static let byteLimit = 1 << 20

    private var frames: [String: (blocks: [TextBlock], bytes: Int)] = [:]
    private var order: [String] = []
    private(set) var bytes = 0

    func blocks(of path: String) -> [TextBlock]? {
        frames[path]?.blocks
    }

    mutating func take(_ blocks: [TextBlock], of path: String, bytes size: Int) {
        if let old = frames.removeValue(forKey: path) {
            bytes -= old.bytes
            order.removeAll { $0 == path }
        }
        frames[path] = (blocks, size)
        order.append(path)
        bytes += size
        while bytes > Self.byteLimit, let oldest = order.first {
            order.removeFirst()
            bytes -= frames.removeValue(forKey: oldest)?.bytes ?? 0
        }
    }

    @concurrent static func read(_ path: String) async -> (blocks: [TextBlock], bytes: Int)? {
        guard let data = FileManager.default.contents(atPath: path), data.count <= Timeline.peekLimit else { return nil }
        let blocks = TextBlock.blocks(in: String(decoding: data, as: UTF8.self))
        guard blocks.first?.fields.first?.key == BlockKind.peek.word else { return nil }
        return (blocks, data.count)
    }
}
