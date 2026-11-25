import AppKit
import OpenspotCore
import os
import SwiftUI

struct SpotBackdropBlur: NSViewRepresentable {
    final class Surface: NSVisualEffectView {
        private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "openspot", category: "glass")
        private static var isReported = false
        private static let kind = "variableBlur"
        private let filter: NSObject?
        private var radius: CGFloat
        private var area: CGRect?
        private var isMoving = false
        private let mask = SpotBackdropMask()
        private var drawn: (radius: CGFloat, fade: SpotBackdropFade, isMoving: Bool)?

        init(radius: CGFloat, area: CGRect?) {
            self.radius = radius
            self.area = area
            let make = NSSelectorFromString("filterWithType:")
            if let type = NSClassFromString("CAFilter") as? NSObject.Type, type.responds(to: make),
               let filter = type.perform(make, with: Self.kind)?.takeUnretainedValue() as? NSObject {
                filter.setValue(Self.kind, forKey: "name")
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

        func take(radius next: CGFloat, area nextArea: CGRect?, isMoving moving: Bool) {
            guard next != radius || nextArea != area || moving != isMoving else { return }
            radius = next
            area = nextArea
            isMoving = moving
            applyBlur(reports: false)
        }

        private func applyBlur(reports: Bool) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            let parts = layer?.sublayers?.flatMap { $0.sublayers ?? [] } ?? []
            guard let filter, let backdrop = parts.first(where: { $0.name == "backdrop" }) else {
                alphaValue = 0
                if reports { Self.report(filter == nil ? "macOS makes no CAFilter of the type \(Self.kind)" : "the visual effect view has no layer named backdrop") }
                return
            }
            alphaValue = 1
            for part in parts { part.isHidden = part.name != "backdrop" }
            if backdrop.filters?.count != 1 || (backdrop.filters?.first as? NSObject) !== filter {
                backdrop.filters = [filter]
                backdrop.setValue(1, forKey: "scale")
                drawn = nil
            }
            let fade = SpotBackdropFade(fade: .current(blur: radius), area: area, size: bounds.size)
            if drawn?.radius != radius {
                backdrop.setValue(radius, forKeyPath: "filters.\(Self.kind).inputRadius")
            }
            if drawn?.fade != fade || drawn?.isMoving != isMoving {
                backdrop.setValue(mask.image(of: fade, isMoving: isMoving), forKeyPath: "filters.\(Self.kind).inputMaskImage")
            }
            drawn = (radius, fade, isMoving)
        }

        private static func report(_ cause: String) {
            guard !isReported else { return }
            isReported = true
            log.error("The backdrop of the panel is not drawn: \(cause, privacy: .public).")
        }
    }

    let radius: CGFloat
    let area: CGRect?
    let isMoving: Bool

    init(radius: CGFloat) {
        self.radius = radius
        area = nil
        isMoving = false
    }

    init(radius: CGFloat, fadingIn area: CGRect, isMoving: Bool) {
        self.radius = radius
        self.area = area
        self.isMoving = isMoving
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface(radius: radius, area: area)
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.appearance = NSAppearance(named: .darkAqua)
        surface.alphaValue = 0
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.take(radius: radius, area: area, isMoving: isMoving)
    }
}
