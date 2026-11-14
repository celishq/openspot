import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class OpenspotItem {
    private static let name = "Openspot"

    private let item = NSStatusBar.system.statusItem(withLength: SpotMenuBarIconView.width)
    private var icon: MenuBarHost<SpotMenuBarIconView>?
    private var drag: SpotMenuBarDrag?

    init(model: SpotsModel, toast: Toast?, target: AnyObject, action: Selector, onDragEnter: @escaping () -> Void, onDrop: @escaping ([URL]) -> Void) {
        #if DEBUG
        let image = NSImage(named: "MenuBarIconNightly")
        #else
        let image = NSImage(named: "MenuBarIcon")
        #endif
        item.button?.image = image
        item.button?.setAccessibilityLabel(Self.name)
        item.button?.target = target
        item.button?.action = action
        drag = item.button.map { SpotMenuBarDrag(button: $0, onEnter: onDragEnter, onDrop: onDrop) }
        icon = makeIcon(model: model, toast: toast)
    }

    var frame: NSRect? {
        item.button?.window.flatMap { $0.occlusionState.contains(.visible) ? $0.frame : nil }
    }

    func contains(_ point: NSPoint) -> Bool {
        item.button?.window?.frame.contains(point) == true
    }

    func show(running summary: String?) {
        icon?.rootView.isWorking = summary != nil
        item.button?.toolTip = summary
        item.button?.setAccessibilityLabel(summary ?? Self.name)
    }

    private func makeIcon(model: SpotsModel, toast: Toast?) -> MenuBarHost<SpotMenuBarIconView>? {
        guard let button = item.button, let image = button.image else { return nil }
        button.image = nil
        let host = MenuBarHost(rootView: SpotMenuBarIconView(model: model, image: image, toast: toast))
        host.frame = NSRect(x: 0, y: 0, width: SpotMenuBarIconView.width, height: button.bounds.height)
        host.autoresizingMask = [.width, .height]
        button.addSubview(host)
        return host
    }
}
