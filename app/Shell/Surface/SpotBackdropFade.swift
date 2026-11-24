import CoreGraphics
import OpenspotCore

struct SpotBackdropFade: Equatable {
    let fade: BackdropFade
    let area: CGRect?
    let size: CGSize

    private static let whole = wholeImage()

    func image() -> CGImage? {
        guard area != nil else { return Self.whole }
        return drawn()?.makeImage()
    }

    func drawn() -> CGContext? {
        guard let area else { return nil }
        let scale = SpotTokens.backdropMaskScale
        guard let context = CGContext(
            data: nil, width: Int((size.width * scale).rounded(.up)), height: Int((size.height * scale).rounded(.up)),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.setBlendMode(.copy)
        for ring in fade.rings(in: area) {
            let frame = CGRect(x: ring.rect.minX, y: size.height - ring.rect.maxY, width: ring.rect.width, height: ring.rect.height)
            context.setFillColor(CGColor(gray: 0, alpha: ring.strength))
            context.addPath(CGPath(roundedRect: frame, cornerWidth: ring.corner, cornerHeight: ring.corner, transform: nil))
            context.fillPath()
        }
        return context
    }

    private static func wholeImage() -> CGImage? {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(CGColor(gray: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context?.makeImage()
    }
}
