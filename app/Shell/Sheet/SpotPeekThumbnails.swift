import AppKit
import OpenspotCore
import QuickLookThumbnailing

@MainActor
final class SpotPeekThumbnails {
    static let shared = SpotPeekThumbnails()

    private static let byteLimit = 16 << 20

    private let images = NSCache<NSString, NSImage>()
    private var loads: [String: Task<NSImage?, Never>] = [:]

    private init() {
        images.totalCostLimit = Self.byteLimit
    }

    func cached(_ path: String) -> NSImage? {
        images.object(forKey: path as NSString)
    }

    func image(_ path: String, scale: CGFloat) async -> NSImage? {
        if let image = cached(path) { return image }
        if let load = loads[path] { return await load.value }
        let side = SpotTokens.peekWidth
        let load = Task<NSImage?, Never> {
            let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: path), size: CGSize(width: side, height: side), scale: scale, representationTypes: .thumbnail)
            return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        }
        loads[path] = load
        let image = await load.value
        loads[path] = nil
        if let image { images.setObject(image, forKey: path as NSString, cost: Int(image.size.width * image.size.height * scale * scale) * 4) }
        return image
    }
}
