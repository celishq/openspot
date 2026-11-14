import AppKit
import ImageIO
import OpenspotCore

@MainActor
final class SpotPictureStore {
    static let shared = SpotPictureStore()
    nonisolated static let scale: CGFloat = 2

    struct Key: Hashable, Sendable {
        let path: String
        let changed: Double?
    }

    private final class Bitmap {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    nonisolated private static let shortSide = Int(max(SpotTokens.gridWidth, SpotTokens.sheetMaxHeight) * scale)
    private static let byteLimit = 16 << 20

    private let bitmaps = NSCache<NSString, Bitmap>()
    private var loads: [Key: Task<CGImage?, Never>] = [:]

    private init() {
        bitmaps.totalCostLimit = Self.byteLimit
    }

    func cached(_ key: Key) -> CGImage? {
        bitmaps.object(forKey: Self.name(of: key))?.image
    }

    func image(_ key: Key) async -> CGImage? {
        if let image = cached(key) { return image }
        if let load = loads[key] { return await load.value }
        let load = Task.detached(priority: .userInitiated) { await WebPictures.shared.path(of: key.path).flatMap(Self.picture(at:)) }
        loads[key] = load
        let image = await load.value
        loads[key] = nil
        if let image { bitmaps.setObject(Bitmap(image), forKey: Self.name(of: key), cost: image.bytesPerRow * image.height) }
        return image
    }

    private static func name(of key: Key) -> NSString {
        "\(key.changed ?? 0)|\(key.path)" as NSString
    }

    private nonisolated static func picture(at path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let short = min(width, height)
            let long = max(width, height)
            let side = short > shortSide ? long * shortSide / short : long
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(side, 1)
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) { return image }
        }
        guard let picture = NSImage(contentsOfFile: path), picture.size.width > 0, picture.size.height > 0 else { return nil }
        let size = picture.size
        let fill = max(1, CGFloat(shortSide) / min(size.width, size.height))
        var rect = CGRect(x: 0, y: 0, width: (size.width * fill).rounded(), height: (size.height * fill).rounded())
        return picture.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
