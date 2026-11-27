import AppKit
import OpenspotCore
import SwiftUI

final class SpotSubmenuWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private final class Content: NSHostingView<SpotSubmenuView> {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    static func make(model: SpotsModel) -> SpotSubmenuWindow {
        let window = SpotSubmenuWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        let content = Content(rootView: SpotSubmenuView(model: model))
        content.sizingOptions = []
        window.contentView = content
        return window
    }

    func show(rows: Int, beside row: CGRect, of menu: CGRect, in panel: NSWindow, at content: NSRect) {
        let size = CGSize(width: SpotTokens.menuWidth, height: SpotTokens.menuHeight(rows: rows))
        let top = content.maxY - (row.minY - SpotTokens.menuPadding)
        let right = content.minX + menu.maxX + SpotTokens.submenuGap
        let left = content.minX + menu.minX - SpotTokens.submenuGap - size.width
        let area = panel.screen?.visibleFrame ?? .infinite
        let x = right + size.width <= area.maxX || left < area.minX ? right : left
        setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: false)
        take(SurfaceEdge(radius: SpotActionMenuView.radius))
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
