import AppKit
import OpenspotCore
import UniformTypeIdentifiers

/// Icons drawn once into small bitmaps, off the main thread, for views to read without any work.
@MainActor
final class SpotIconStore {
    static let shared = SpotIconStore()
    static let scale: CGFloat = 2

    nonisolated private static let pixels = 72

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
        bitmaps.countLimit = 2000
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
        if let image { bitmaps.setObject(Bitmap(image), forKey: Self.name(of: icon)) }
        return image
    }

    /// Draws the icons of these items, and returns when they are ready.
    func prepare(_ items: [SpotItem]) async {
        let icons = Set(items.compactMap { $0.file.map(FileIcon.init(path:)) })
        await withTaskGroup(of: Void.self) { group in
            for icon in icons where cached(icon) == nil {
                group.addTask { _ = await self.image(icon) }
            }
        }
    }

    private func draw(_ icon: FileIcon) async -> CGImage? {
        await withCheckedContinuation { continuation in
            drawing.addOperation {
                continuation.resume(returning: Self.bitmap(of: icon))
            }
        }
    }

    private static func name(of icon: FileIcon) -> NSString {
        switch icon {
        case .file(let path): "file:\(path)" as NSString
        case .type(let suffix): "type:\(suffix)" as NSString
        }
    }

    private nonisolated static func bitmap(of icon: FileIcon) -> CGImage? {
        let source: NSImage
        switch icon {
        case .file(let path): source = NSWorkspace.shared.icon(forFile: path)
        case .type(let suffix): source = NSWorkspace.shared.icon(for: UTType(filenameExtension: suffix) ?? .data)
        }
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
        source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }
}
