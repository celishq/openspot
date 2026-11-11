import AppKit
import OpenspotCore
import UniformTypeIdentifiers

/// Icons drawn once into small bitmaps, off the main thread, for views to read without any work.
@MainActor
final class SpotIconStore {
    static let shared = SpotIconStore()
    static let scale: CGFloat = 2

    nonisolated private static let pixels = 72
    private static let byteLimit = 4 << 20

    private final class Bitmap {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    private let bitmaps = NSCache<NSString, Bitmap>()
    private var loads: [FileIcon: Task<CGImage?, Never>] = [:]
    private let drawing = OperationQueue()

    private init() {
        bitmaps.totalCostLimit = Self.byteLimit
        drawing.maxConcurrentOperationCount = 4
        drawing.qualityOfService = .userInteractive
    }

    func cached(_ icon: FileIcon) -> CGImage? {
        bitmaps.object(forKey: Self.name(of: icon))?.image
    }

    func image(_ icon: FileIcon) async -> CGImage? {
        if let image = cached(icon) { return image }
        if let load = loads[icon] { return await load.value }
        let load = Task { await draw(icon) }
        loads[icon] = load
        let image = await load.value
        loads[icon] = nil
        if let image { bitmaps.setObject(Bitmap(image), forKey: Self.name(of: icon), cost: image.bytesPerRow * image.height) }
        return image
    }

    /// Draws the icons of these items, and returns when they are ready.
    func prepare(_ items: [SpotItem]) async {
        let icons = Set(items.compactMap(\.icon))
        await withTaskGroup(of: Void.self) { group in
            for icon in icons where cached(icon) == nil {
                group.addTask { _ = await self.image(icon) }
            }
        }
    }

    /// Draws an icon, after it fetches a picture on the web into a file.
    private func draw(_ icon: FileIcon) async -> CGImage? {
        var file = icon
        if case .image(let path) = icon {
            guard let kept = await WebPictures.shared.path(of: path) else { return nil }
            file = .image(kept)
        }
        let drawn = file
        return await withCheckedContinuation { continuation in
            drawing.addOperation {
                continuation.resume(returning: Self.bitmap(of: drawn))
            }
        }
    }

    private static func name(of icon: FileIcon) -> NSString {
        switch icon {
        case .file(let path): "file:\(path)" as NSString
        case .type(let suffix): "type:\(suffix)" as NSString
        case .image(let path): "image:\(path)" as NSString
        }
    }

    /// Draws the picture of an image file in its whole square, and a Finder icon with its body at the share of an app icon.
    private nonisolated static func bitmap(of icon: FileIcon) -> CGImage? {
        switch icon {
        case .file(let path): bodied(NSWorkspace.shared.icon(forFile: path))
        case .type(let suffix): bodied(NSWorkspace.shared.icon(for: UTType(filenameExtension: suffix) ?? .data))
        case .image(let path): NSImage(contentsOfFile: path).flatMap { square($0, in: NSRect(x: 0, y: 0, width: pixels, height: pixels))?.makeImage() }
        }
    }

    private nonisolated static func bodied(_ source: NSImage) -> CGImage? {
        guard let whole = square(source, in: NSRect(x: 0, y: 0, width: pixels, height: pixels)), let data = whole.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: whole.bytesPerRow * pixels)
        let alpha = (0..<pixels * pixels).map { bytes[($0 / pixels) * whole.bytesPerRow + ($0 % pixels) * 4 + 3] }
        let frame = IconBody(alpha: alpha, side: pixels).frame(in: CGFloat(pixels))
        return square(source, in: NSRect(x: frame.minX, y: CGFloat(pixels) - frame.maxY, width: frame.width, height: frame.height))?.makeImage()
    }

    private nonisolated static func square(_ source: NSImage, in rect: NSRect) -> CGContext? {
        guard let context = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        source.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        return context
    }
}
