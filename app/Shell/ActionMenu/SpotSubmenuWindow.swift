import AppKit
import OpenspotCore
import SwiftUI

final class SpotSubmenuWindow: NSPanel {
    private static let menuGap: CGFloat = 4

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

    func show(rows: Int, beside row: CGRect, of menu: CGRect, in panel: NSWindow) {
        let size = CGSize(width: ActionMenuFrame.width, height: SpotTokens.menuHeight(rows: rows))
        let top = panel.frame.maxY - (row.minY - SpotTokens.menuPadding)
        let right = panel.frame.minX + menu.maxX + Self.menuGap
        let left = panel.frame.minX + menu.minX - Self.menuGap - size.width
        let area = panel.screen?.visibleFrame ?? .infinite
        let x = right + size.width <= area.maxX || left < area.minX ? right : left
        setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: false)
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
