import AppKit
import OpenspotCore
import SwiftUI

/// One blur of what lies behind the window, with the theme's shade. The shade grows from nothing at its edge across the
/// whole margin, and the blur grows only close to the content.
struct SpotSoftBlur: NSViewRepresentable {
    private static let blurInset: CGFloat = SpotTokens.halo - 5
    private static let blurSoftness: CGFloat = 20
    private static let tintInset: CGFloat = SpotTokens.halo * 0.58
    private static let tintSoftness: CGFloat = SpotTokens.halo / 4.7

    /// Images of alpha alone, which is the strength of the blur and of the tint at each point.
    struct Masks {
        let blur: CGImage?
        let tint: CGImage?
    }

    let height: CGFloat
    var width = SpotTokens.panelWidth

    /// The size of a pair of masks.
    private struct Size: Hashable {
        let width: CGFloat
        let height: CGFloat
    }

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
        surface.masks = Self.masks(Size(width: width, height: height))
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.isDark = context.environment.colorScheme == .dark
        surface.masks = Self.masks(Size(width: width, height: height))
    }

    /// The masks of each size, 8 MB beside two of the largest pairs. Each surface asks for its size on each update, so the
    /// sizes in use are the last to go.
    private static var kept = RecentCache<Size, Masks>(base: 8 << 20)

    /// Draws the masks of these heights at this width ahead in their order, one in each turn of the main queue, so that an
    /// open of a sheet finds them. It stops where the next pair would push out a kept one.
    static func warm(_ heights: [CGFloat], width: CGFloat) {
        var left = heights[...]
        while let height = left.first, kept.value(for: Size(width: width, height: height)) != nil { left = left.dropFirst() }
        guard let height = left.first, cost(of: Size(width: width, height: height)) <= kept.room else { return }
        _ = masks(Size(width: width, height: height))
        DispatchQueue.main.async { warm(Array(left.dropFirst()), width: width) }
    }

    /// The most bytes that the pair of masks of this size can take, with room for the padding of its rows.
    private static func cost(of size: Size) -> Int {
        2 * (Int(size.width.rounded(.up)) + 64) * Int(size.height.rounded(.up))
    }

    /// The masks of this size.
    private static func masks(_ size: Size) -> Masks {
        if let masks = kept.value(for: size) { return masks }
        let masks = Masks(
            blur: mask(size, inset: blurInset, softness: blurSoftness),
            tint: mask(size, inset: tintInset, softness: tintSoftness)
        )
        kept.keep(masks, for: size, cost: [masks.blur, masks.tint].reduce(0) { $0 + ($1.map { $0.bytesPerRow * $0.height } ?? 0) })
        return masks
    }

    /// Draws a soft rounded shape and keeps only its alpha, a quarter of the bytes of the drawing.
    private static func mask(_ size: Size, inset: CGFloat, softness: CGFloat) -> CGImage? {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius + SpotTokens.halo - inset, style: .continuous)
            .fill(Color.black)
            .padding(inset)
            .frame(width: size.width, height: size.height)
            .blur(radius: softness)
        guard let drawn = ImageRenderer(content: shape).cgImage,
              let alpha = CGContext(data: nil, width: drawn.width, height: drawn.height, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
        else { return nil }
        alpha.draw(drawn, in: CGRect(x: 0, y: 0, width: drawn.width, height: drawn.height))
        return alpha.makeImage()
    }
}
