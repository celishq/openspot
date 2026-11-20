import AppKit
import ImageIO
import OpenspotCore

@MainActor
final class SpotPictureStore {
    static let shared = SpotPictureStore()

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

    private static var shortSide: Int { Int(max(SpotTokens.gridWidth, SpotTokens.sheetMaxHeight) * SpotTokens.pictureScale) }
    private static let byteLimit = 16 << 20

    private let bitmaps = NSCache<NSString, AnyObject>()
    private var loads: [Key: Task<CGImage?, Never>] = [:]
    private var frameLoads: [Key: Task<PictureFrames?, Never>] = [:]

    private init() {
        bitmaps.totalCostLimit = Self.byteLimit
    }

    func cached(_ key: Key) -> CGImage? {
        (bitmaps.object(forKey: Self.name(of: key)) as? Bitmap)?.image
    }

    func cachedFrames(_ key: Key) -> PictureFrames? {
        bitmaps.object(forKey: Self.name(of: key)) as? PictureFrames
    }

    func frames(_ key: Key) async -> PictureFrames? {
        if let frames = cachedFrames(key) { return frames }
        if let load = frameLoads[key] { return await load.value }
        let shortSide = Self.shortSide
        let bytes = Self.byteLimit
        let load = Task.detached(priority: .userInitiated) { await WebPictures.shared.path(of: key.path).flatMap { PictureFile(path: $0).readFrames(shortSide: shortSide, bytes: bytes) } }
        frameLoads[key] = load
        let frames = await load.value
        frameLoads[key] = nil
        if let frames { bitmaps.setObject(frames, forKey: Self.name(of: key), cost: frames.bytes) }
        return frames
    }

    func image(_ key: Key) async -> CGImage? {
        if let image = cached(key) { return image }
        if let load = loads[key] { return await load.value }
        let shortSide = Self.shortSide
        let load = Task.detached(priority: .userInitiated) { await WebPictures.shared.path(of: key.path).flatMap { Self.picture(at: $0, shortSide: shortSide) } }
        loads[key] = load
        let image = await load.value
        loads[key] = nil
        if let image { bitmaps.setObject(Bitmap(image), forKey: Self.name(of: key), cost: image.bytesPerRow * image.height) }
        return image
    }

    private static func name(of key: Key) -> NSString {
        "\(shortSide)|\(key.changed ?? 0)|\(key.path)" as NSString
    }

    private nonisolated static func picture(at path: String, shortSide: Int) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let short = min(width, height)
            let long = max(width, height)
            let filled = short > shortSide ? long * shortSide / short : long
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(filled, 1)
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) { return image }
        }
        guard let picture = NSImage(contentsOfFile: path), picture.size.width > 0, picture.size.height > 0 else { return nil }
        let size = picture.size
        let fill = max(1, CGFloat(shortSide) / min(size.width, size.height))
        var rect = CGRect(x: 0, y: 0, width: max((size.width * fill).rounded(), 1), height: max((size.height * fill).rounded(), 1))
        return picture.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
