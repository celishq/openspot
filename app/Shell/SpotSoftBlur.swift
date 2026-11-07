import AppKit
import SwiftUI

/// One blur of what lies behind the window, with a dark tint. The tint grows from nothing at its edge across the whole margin,
/// and the blur grows only close to the content.
struct SpotSoftBlur: NSViewRepresentable {
    private static let blurInset: CGFloat = SpotTokens.halo - 5
    private static let blurSoftness: CGFloat = 20
    private static let tintInset: CGFloat = SpotTokens.halo * 0.58
    private static let tintSoftness: CGFloat = SpotTokens.halo / 4.7
    private static let cardInset: CGFloat = SpotTokens.halo - 20
    private static let cardSoftness: CGFloat = 8

    /// Black images whose alpha is the strength of the blur and of the tint at each point.
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
                filter = Self.filter(mask: masks?.blur, radius: theme.backdropBlur)
                applyBlur()
            }
        }

        /// The theme that sets its tint and its blur. The system view stays dark, because only there it has the backdrop layer.
        var theme = SpotTheme.dark {
            didSet {
                guard theme.backdropBlur != oldValue.backdropBlur || theme.tint != oldValue.tint else { return }
                filter = Self.filter(mask: masks?.blur, radius: theme.backdropBlur)
                needsLayout = true
                applyBlur()
            }
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
            tint.backgroundColor = theme.tint.cgColor
            applyBlur()
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
        surface.theme = SpotTheme.palette(for: context.environment.colorScheme)
        surface.masks = Self.masks(height: height)
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.theme = SpotTheme.palette(for: context.environment.colorScheme)
        surface.masks = Self.masks(height: height)
    }

    private static var keptCardMasks: [CGFloat: Image] = [:]

    /// The soft shape that ends the cards of a panel this tall. It is whole under the grid, and fades out inside the blur.
    static func cardMask(height: CGFloat) -> Image {
        if let image = keptCardMasks[height] { return image }
        let image = mask(height: height, inset: cardInset, softness: cardSoftness).map { Image(decorative: $0, scale: 1) } ?? Image(systemName: "square.fill")
        keptCardMasks[height] = image
        return image
    }

    private static var kept: [CGFloat: Masks] = [:]

    /// The masks of this height, kept for each height.
    private static func masks(height: CGFloat) -> Masks {
        if let masks = kept[height] { return masks }
        let masks = Masks(
            blur: mask(height: height, inset: blurInset, softness: blurSoftness),
            tint: mask(height: height, inset: tintInset, softness: tintSoftness)
        )
        kept[height] = masks
        return masks
    }

    private static func mask(height: CGFloat, inset: CGFloat, softness: CGFloat) -> CGImage? {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius + SpotTokens.halo - inset, style: .continuous)
            .fill(Color.black)
            .padding(inset)
            .frame(width: SpotTokens.panelWidth, height: height)
            .blur(radius: softness)
        return ImageRenderer(content: shape).cgImage
    }
}
