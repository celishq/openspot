import AppKit
import SwiftUI

struct SpotBlur: View, @preconcurrency Animatable {
    var radius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.spotDrawsBlur) private var drawsBlur

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    var body: some View {
        if drawsBlur {
            Backing(radius: radius, isTinted: SpotTheme.palette(for: scheme).isMaterialTinted)
        } else {
            Color.clear
        }
    }
}

private struct Backing: NSViewRepresentable {
    var radius: CGFloat
    var isTinted: Bool

    final class Surface: NSVisualEffectView {
        var radius: CGFloat = 0
        var isTinted = false
        private weak var backdrop: CALayer?
        private var saturation: NSObject?

        override func layout() {
            super.layout()
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
            DispatchQueue.main.async { self.applyBlur() }
        }

        func applyBlur() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            layer?.sublayers?.flatMap { $0.sublayers ?? [] }.forEach { part in
                part.isHidden = !isTinted && part.name != "backdrop"
                guard part.name == "backdrop" else { return }
                let filters = part.filters ?? []
                let found = filters.first { ($0 as? NSObject)?.value(forKey: "name") as? String == "colorSaturate" } as? NSObject
                if let found { saturation = found }
                if isTinted, found == nil, let saturation {
                    part.filters = filters + [saturation]
                } else if !isTinted, let found {
                    part.filters = filters.filter { ($0 as? NSObject) !== found }
                }
                part.setValue(radius, forKeyPath: "filters.gaussianBlur.inputRadius")
                backdrop = part
            }
        }

        func applyRadius() {
            guard let backdrop, backdrop.superlayer != nil else { return applyBlur() }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            backdrop.setValue(radius, forKeyPath: "filters.gaussianBlur.inputRadius")
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface()
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.appearance = NSAppearance(named: .darkAqua)
        surface.radius = radius
        surface.isTinted = isTinted
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        if surface.isTinted != isTinted {
            surface.isTinted = isTinted
            surface.radius = radius
            return surface.applyBlur()
        }
        guard surface.radius != radius else { return }
        surface.radius = radius
        surface.applyRadius()
    }
}
