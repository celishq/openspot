import AppKit
import OpenspotCore

extension NSWindow {
    func take(_ edge: SurfaceEdge) {
        contentView?.wantsLayer = true
        guard let layer = contentView?.layer else { return }
        let bounds = CGRect(origin: .zero, size: frame.size)
        layer.cornerRadius = edge.corner(in: bounds)
        layer.cornerCurve = edge.isCircular(in: bounds) ? .circular : .continuous
        layer.masksToBounds = true
        invalidateShadow()
    }
}
