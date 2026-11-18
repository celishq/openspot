import AppKit
import os
import SwiftUI

struct SpotBackdropBlur: NSViewRepresentable {
    final class Surface: NSVisualEffectView {
        private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "openspot", category: "glass")
        private static var isReported = false
        private let filter: NSObject?
        private var radius: CGFloat

        init(radius: CGFloat) {
            self.radius = radius
            let make = NSSelectorFromString("filterWithType:")
            if let type = NSClassFromString("CAFilter") as? NSObject.Type, type.responds(to: make),
               let filter = type.perform(make, with: "gaussianBlur")?.takeUnretainedValue() as? NSObject {
                filter.setValue(radius, forKey: "inputRadius")
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

        func take(radius next: CGFloat) {
            guard next != radius, let filter else { return }
            radius = next
            filter.setValue(next, forKey: "inputRadius")
            applyBlur(reports: false, isNew: true)
        }

        private func applyBlur(reports: Bool, isNew: Bool = false) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            let parts = layer?.sublayers?.flatMap { $0.sublayers ?? [] } ?? []
            guard let filter, let backdrop = parts.first(where: { $0.name == "backdrop" }) else {
                alphaValue = 0
                if reports { Self.report(filter == nil ? "macOS makes no CAFilter of the type gaussianBlur" : "the visual effect view has no layer named backdrop") }
                return
            }
            alphaValue = 1
            for part in parts { part.isHidden = part.name != "backdrop" }
            guard isNew || backdrop.filters?.count != 1 || (backdrop.filters?.first as? NSObject) !== filter else { return }
            backdrop.filters = [filter]
            backdrop.setValue(1, forKey: "scale")
        }

        private static func report(_ cause: String) {
            guard !isReported else { return }
            isReported = true
            log.error("The backdrop of the panel is not drawn: \(cause, privacy: .public).")
        }
    }

    let radius: CGFloat

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface(radius: radius)
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.appearance = NSAppearance(named: .darkAqua)
        surface.alphaValue = 0
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.take(radius: radius)
    }
}
