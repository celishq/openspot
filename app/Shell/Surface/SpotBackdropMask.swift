import CoreGraphics
import Foundation
import OpenspotCore

final class SpotBackdropMask {
    private static let keptLimit = 2
    private var kept: [(fade: SpotBackdropFade, image: CGImage?)] = []
    private var tallest: (fade: SpotBackdropFade, picture: CGContext?)?

    func image(of fade: SpotBackdropFade, isMoving: Bool) -> CGImage? {
        if let shown = kept.first(where: { $0.fade == fade }) { return shown.image }
        if isMoving { return stretched(to: fade) ?? fade.image() }
        let image = fade.image()
        kept = Array((kept + [(fade, image)]).suffix(Self.keptLimit))
        return image
    }

    private func stretched(to fade: SpotBackdropFade) -> CGImage? {
        guard let area = fade.area else { return nil }
        let tallArea = CGRect(x: area.minX, y: area.minY, width: area.width, height: fade.size.height - area.minY)
        let tall = SpotBackdropFade(fade: fade.fade, area: tallArea, size: fade.size)
        if tallest?.fade != tall { tallest = (tall, tall.drawn()) }
        guard let picture = tallest?.picture, let source = picture.data, let space = picture.colorSpace,
              let stretch = fade.fade.stretch(from: tallArea, to: area, height: fade.size.height, scale: SpotTokens.backdropMaskScale) else { return nil }
        let row = picture.bytesPerRow
        let rows = picture.height
        let below = max(rows - stretch.split - stretch.shift, 0)
        var pixels = Data(count: rows * row)
        pixels.withUnsafeMutableBytes { target in
            guard let start = target.baseAddress else { return }
            start.copyMemory(from: source, byteCount: min(stretch.split, rows) * row)
            if below > 0 { (start + stretch.split * row).copyMemory(from: source + (stretch.split + stretch.shift) * row, byteCount: below * row) }
        }
        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        return CGImage(
            width: picture.width, height: rows, bitsPerComponent: picture.bitsPerComponent, bitsPerPixel: picture.bitsPerPixel, bytesPerRow: row,
            space: space, bitmapInfo: picture.bitmapInfo, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }
}
