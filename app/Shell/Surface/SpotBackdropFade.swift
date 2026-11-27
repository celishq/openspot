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
        area.flatMap { fade.picture(of: $0, size: size, scale: SpotTokens.backdropMaskScale) }
    }

    private static func wholeImage() -> CGImage? {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(CGColor(gray: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context?.makeImage()
    }
}
