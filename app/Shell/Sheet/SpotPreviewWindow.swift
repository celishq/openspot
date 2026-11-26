import AppKit
import OpenspotCore
import SwiftUI

final class SpotPreviewWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func make(model: SpotsModel) -> SpotPreviewWindow {
        let window = SpotPreviewWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        let content = NSHostingView(rootView: SpotPreviewView(model: model))
        content.sizingOptions = []
        window.contentView = content
        return window
    }

    func show(beside sheet: CGRect, in panel: NSWindow) {
        guard let area = panel.screen?.visibleFrame else { return hide() }
        let right = panel.frame.minX + sheet.maxX + SpotTokens.previewGap
        let leftEdge = panel.frame.minX + sheet.minX - SpotTokens.previewGap
        let room = max(area.maxX - right, leftEdge - area.minX)
        let width = min(area.width * SpotTokens.previewScreenShare, room)
        guard width >= SpotTokens.previewMinWidth else { return hide() }
        let x = area.maxX - right >= width ? right : leftEdge - width
        let top = panel.frame.maxY - sheet.minY
        setFrame(NSRect(x: x, y: top - sheet.height, width: width, height: sheet.height), display: false)
        take(SurfaceEdge.sheet)
        level = panel.level
        if parent !== panel {
            parent?.removeChildWindow(self)
            panel.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    func hide() {
        parent?.removeChildWindow(self)
        orderOut(nil)
    }
}
