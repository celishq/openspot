import AppKit
import OpenspotCore
import SwiftUI

/// One blur of what lies behind the window, with the theme's shade. The shade grows from nothing at its edge across the
/// whole margin. The blur is full at the content and falls along `blurFalloff` to nothing at the window's edge.
struct SpotSoftBlur: NSViewRepresentable {
    /// The strength that the blur loses with the distance from the content, as a share of the margin.
    private static let blurFalloff = UnitCurve.bezier(
        startControlPoint: SpotTheme.backdropFalloff.start,
        endControlPoint: SpotTheme.backdropFalloff.end
    )
    private static let tintInset: CGFloat = SpotTokens.halo * 0.58
    private static let tintSoftness: CGFloat = SpotTokens.halo / 4.7

    /// Images of alpha alone, which is the strength of the blur and of the tint at each point.
    struct Masks {
        let blur: CGImage?
        let tint: CGImage?
    }

    let height: CGFloat

    final class Surface: NSVisualEffectView {
        private static let filterType = "variableBlur"

        var masks: Masks? {
            didSet {
                guard masks?.blur !== oldValue?.blur else { return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                defer { CATransaction.commit() }
                tintMask.contents = masks?.tint
                filter = Self.filter(mask: masks?.blur, radius: SpotTheme.backdropBlur)
                applyBlur()
            }
        }

        /// Whether the panel is in the dark theme, which picks the shade of the tint.
        var isDark = true {
            didSet { if isDark != oldValue { applyShade() } }
        }

        private let tint = CALayer()
        private let tintMask = CALayer()

        private var filter: NSObject?
        private var appliedFilter: NSObject?

        /// A filter holds its mask from the first time it draws, so each mask has a filter of its own.
        private static func filter(mask: CGImage?, radius: CGFloat) -> NSObject? {
            let filter = (NSClassFromString("CAFilter") as? NSObject.Type)?
                .perform(NSSelectorFromString("filterWithType:"), with: filterType)?
                .takeUnretainedValue() as? NSObject
            filter?.setValue(radius, forKey: "inputRadius")
            filter?.setValue(true, forKey: "inputNormalizeEdges")
            filter?.setValue(mask, forKey: "inputMaskImage")
            return filter
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            if tint.superlayer == nil {
                tint.zPosition = 1
                tint.mask = tintMask
                layer?.addSublayer(tint)
            }
            tint.frame = bounds
            tintMask.frame = bounds
            applyShade()
            applyBlur()
        }

        /// Gives the tint the shade of the theme that the panel is in.
        private func applyShade() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            tint.backgroundColor = (isDark ? SpotTheme.dark : SpotTheme.light).shade.cgColor
        }

        override func updateLayer() {
            super.updateLayer()
            applyBlur()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { self.applyBlur() }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsLayout = true
            DispatchQueue.main.async { self.applyBlur() }
        }

        private func applyBlur() {
            guard let filter else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            layer?.sublayers?.filter { $0 !== tint }.flatMap { $0.sublayers ?? [] }.forEach { part in
                part.isHidden = part.name != "backdrop"
                guard part.name == "backdrop", appliedFilter !== filter || part.filters?.count != 1 else { return }
                appliedFilter = filter
                part.filters = [filter]
                part.setValue(1, forKey: "scale")
            }
        }
    }

    /// Fills the surface it lies on, so that a resize asks AppKit for no size of its own.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface()
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.appearance = NSAppearance(named: .darkAqua)
        surface.isDark = context.environment.colorScheme == .dark
        surface.masks = Self.masks(height: height)
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.isDark = context.environment.colorScheme == .dark
        surface.masks = Self.masks(height: height)
    }

    private static var kept: [CGFloat: Masks] = [:]

    /// Draws the masks of these heights ahead, one in each turn of the main queue, so that an open of a sheet finds them.
    static func warm(_ heights: [CGFloat]) {
        var left = Set(heights).subtracting(kept.keys)
        guard let height = left.popFirst() else { return }
        _ = masks(height: height)
        DispatchQueue.main.async { warm(Array(left)) }
    }

    /// The masks of this height, kept for each height.
    private static func masks(height: CGFloat) -> Masks {
        if let masks = kept[height] { return masks }
        let masks = Masks(
            blur: falloff(height: height),
            tint: mask(height: height, inset: tintInset, softness: tintSoftness)
        )
        kept[height] = masks
        return masks
    }

    /// The blur's mask: full inside the content, whose corners are those of the panel, and weaker by `blurFalloff` with the
    /// distance out from it, to nothing at the window's edge. It works out one quarter and mirrors it into the others.
    private static func falloff(height: CGFloat) -> CGImage? {
        let width = Int(SpotTokens.panelWidth)
        let rows = Int(height)
        guard width > 0, rows > 0,
              let context = CGContext(data: nil, width: width, height: rows, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
              let data = context.data
        else { return nil }
        let levels = (0...255).map { UInt8((255 * min(max(1 - blurFalloff.value(at: Double($0) / 255), 0), 1)).rounded()) }
        let margin = SpotTokens.halo
        let corner = SpotTokens.radius
        let reach = CGSize(width: max(CGFloat(width) / 2 - margin - corner, 0), height: max(CGFloat(rows) / 2 - margin - corner, 0))
        let line = context.bytesPerRow
        let bytes = data.bindMemory(to: UInt8.self, capacity: line * rows)
        for y in 0..<(rows + 1) / 2 {
            let along = abs(CGFloat(y) + 0.5 - CGFloat(rows) / 2) - reach.height
            for x in 0..<(width + 1) / 2 {
                let across = abs(CGFloat(x) + 0.5 - CGFloat(width) / 2) - reach.width
                let distance = hypot(max(across, 0), max(along, 0)) + min(max(across, along), 0) - corner
                let level = levels[Int(min(max(distance / margin, 0), 1) * 255)]
                let top = y * line
                let bottom = (rows - 1 - y) * line
                bytes[top + x] = level
                bytes[top + width - 1 - x] = level
                bytes[bottom + x] = level
                bytes[bottom + width - 1 - x] = level
            }
        }
        return context.makeImage()
    }

    /// Draws a soft rounded shape and keeps only its alpha, a quarter of the bytes of the drawing.
    private static func mask(height: CGFloat, inset: CGFloat, softness: CGFloat) -> CGImage? {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius + SpotTokens.halo - inset, style: .continuous)
            .fill(Color.black)
            .padding(inset)
            .frame(width: SpotTokens.panelWidth, height: height)
            .blur(radius: softness)
        guard let drawn = ImageRenderer(content: shape).cgImage,
              let alpha = CGContext(data: nil, width: drawn.width, height: drawn.height, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
        else { return nil }
        alpha.draw(drawn, in: CGRect(x: 0, y: 0, width: drawn.width, height: drawn.height))
        return alpha.makeImage()
    }
}
