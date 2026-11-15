import AppKit
import OpenspotCore
import SwiftUI

struct SpotSoftBlur: NSViewRepresentable {
    final class Surface: NSVisualEffectView {
        private static let filter: NSObject? = {
            let filter = (NSClassFromString("CAFilter") as? NSObject.Type)?
                .perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur")?
                .takeUnretainedValue() as? NSObject
            filter?.setValue(SpotTheme.backdropBlur, forKey: "inputRadius")
            filter?.setValue(true, forKey: "inputNormalizeEdges")
            return filter
        }()

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

        private func applyBlur() {
            guard let filter = Self.filter else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            layer?.sublayers?.flatMap { $0.sublayers ?? [] }.forEach { part in
                part.isHidden = part.name != "backdrop"
                guard part.name == "backdrop", part.filters?.count != 1 || (part.filters?.first as? NSObject) !== filter else { return }
                part.filters = [filter]
                part.setValue(1, forKey: "scale")
            }
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
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {}
}
