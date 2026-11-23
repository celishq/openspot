import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class OpenspotItem {
    private static let name = "Openspot"

    private let item = NSStatusBar.system.statusItem(withLength: SpotTokens.menuBarPill.width)
    private var icon: MenuBarHost<OpenspotItemView>?
    private var drag: SpotMenuBarDrag?

    init(model: SpotsModel, toast: Toast?, target: AnyObject, action: Selector, onDragEnter: @escaping () -> Void, onDrop: @escaping ([URL]) -> Void) {
        #if DEBUG
        let image = NSImage(named: "MenuBarIconNightly")
        #else
        let image = NSImage(named: "MenuBarIcon")
        #endif
        item.button?.setAccessibilityLabel(Self.name)
        item.button?.target = target
        item.button?.action = action
        drag = item.button.map { SpotMenuBarDrag(button: $0, onEnter: onDragEnter, onDrop: onDrop) }
        icon = image.flatMap { makeIcon(model: model, image: $0, toast: toast) }
    }

    var frame: NSRect? {
        item.button?.window.flatMap { $0.occlusionState.contains(.visible) ? $0.frame : nil }
    }

    func contains(_ point: NSPoint) -> Bool {
        item.button?.window?.frame.contains(point) == true
    }

    func show(running summary: String?) {
        item.button?.toolTip = summary
        item.button?.setAccessibilityLabel(summary ?? Self.name)
    }

    private func makeIcon(model: SpotsModel, image: NSImage, toast: Toast?) -> MenuBarHost<OpenspotItemView>? {
        guard let button = item.button else { return nil }
        let host = MenuBarHost(rootView: OpenspotItemView(model: model, image: image, toast: toast))
        let height = max(button.bounds.height, SpotTokens.menuBarPill.height)
        host.frame = NSRect(x: 0, y: (button.bounds.height - height) / 2, width: SpotTokens.menuBarPill.width, height: height)
        host.autoresizingMask = [.width, .height]
        button.addSubview(host)
        return host
    }
}
