import AppKit
import OpenspotCore
import os
import SwiftUI

struct SpotBackdropBlur: NSViewRepresentable {
    final class Surface: NSVisualEffectView {
        private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "openspot", category: "glass")
        private static var isReported = false
        private static let whole = wholeMask()
        private let filter: NSObject?
        private var radius: CGFloat
        private var rect: CGRect?
        private var drawn: (radius: CGFloat, rect: CGRect?, size: CGSize)?

        init(radius: CGFloat, rect: CGRect?) {
            self.radius = radius
            self.rect = rect
            let make = NSSelectorFromString("filterWithType:")
            if let type = NSClassFromString("CAFilter") as? NSObject.Type, type.responds(to: make),
               let filter = type.perform(make, with: "variableBlur")?.takeUnretainedValue() as? NSObject {
                filter.setValue("variableBlur", forKey: "name")
                filter.setValue(true, forKey: "inputNormalizeEdges")
                self.filter = filter
            } else {
                filter = nil
            }
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func layout() {
            super.layout()
            applyBlur(reports: false)
        }

        override func updateLayer() {
            super.updateLayer()
            applyBlur(reports: false)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { self.applyBlur(reports: self.window != nil) }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            DispatchQueue.main.async { self.applyBlur(reports: false) }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        func take(radius next: CGFloat, rect nextRect: CGRect?) {
            guard next != radius || nextRect != rect else { return }
            radius = next
            rect = nextRect
            applyBlur(reports: false)
        }

        private func applyBlur(reports: Bool) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            let parts = layer?.sublayers?.flatMap { $0.sublayers ?? [] } ?? []
            guard let filter, let backdrop = parts.first(where: { $0.name == "backdrop" }) else {
                alphaValue = 0
                if reports { Self.report(filter == nil ? "macOS makes no CAFilter of the type variableBlur" : "the visual effect view has no layer named backdrop") }
                return
            }
            alphaValue = 1
            for part in parts { part.isHidden = part.name != "backdrop" }
            if backdrop.filters?.count != 1 || (backdrop.filters?.first as? NSObject) !== filter {
                backdrop.filters = [filter]
                backdrop.setValue(1, forKey: "scale")
                drawn = nil
            }
            let size = bounds.size
            if drawn?.radius != radius {
                backdrop.setValue(radius, forKeyPath: "filters.variableBlur.inputRadius")
            }
            if drawn?.rect != rect || drawn?.size != size {
                backdrop.setValue(rect.flatMap { Self.mask(of: $0, in: size) } ?? Self.whole, forKeyPath: "filters.variableBlur.inputMaskImage")
            }
            drawn = (radius, rect, size)
        }

        private static func mask(of rect: CGRect, in size: CGSize) -> CGImage? {
            let scale = SpotTokens.backdropMaskScale
            guard let context = CGContext(
                data: nil, width: Int((size.width * scale).rounded(.up)), height: Int((size.height * scale).rounded(.up)),
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.scaleBy(x: scale, y: scale)
            context.setBlendMode(.copy)
            for ring in BackdropFade(backdrop: SpotTokens.backdrop).rings(around: rect.insetBy(dx: SpotTokens.halo, dy: SpotTokens.halo)) {
                let frame = CGRect(x: ring.rect.minX, y: size.height - ring.rect.maxY, width: ring.rect.width, height: ring.rect.height)
                let corner = min(ring.corner, frame.width / 2, frame.height / 2)
                context.setFillColor(CGColor(gray: 0, alpha: ring.strength))
                context.addPath(CGPath(roundedRect: frame, cornerWidth: corner, cornerHeight: corner, transform: nil))
                context.fillPath()
            }
            return context.makeImage()
        }

        private static func wholeMask() -> CGImage? {
            let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.setFillColor(CGColor(gray: 0, alpha: 1))
            context?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            return context?.makeImage()
        }

        private static func report(_ cause: String) {
            guard !isReported else { return }
            isReported = true
            log.error("The backdrop of the panel is not drawn: \(cause, privacy: .public).")
        }
    }

    let radius: CGFloat
    var rect: CGRect?

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface(radius: radius, rect: rect)
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.appearance = NSAppearance(named: .darkAqua)
        surface.alphaValue = 0
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.take(radius: radius, rect: rect)
    }
}
