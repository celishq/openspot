import AppKit
import OpenspotCore
import SwiftUI

/// The Openspot item in the menu bar. It draws the app's icon, which a pressed command's or a toast's symbol swaps for a
/// moment, shows running work in place of the icon, takes a drop of `.spot` files, and says where it shows on screen.
@MainActor
final class OpenspotItem {
    private static let name = "Openspot"

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let iconWidth: CGFloat
    private var icon: MenuBarHost<SpotTrayIconView>?
    private var work: MenuBarMarkItem?
    private var drag: SpotMenuBarDrag?

    init(model: SpotsModel, toast: Toast?, target: AnyObject, action: Selector, onDragEnter: @escaping () -> Void, onDrop: @escaping ([URL]) -> Void) {
        #if DEBUG
        let image = NSImage(named: "TrayMarkNightly")
        #else
        let image = NSImage(named: "TrayMark")
        #endif
        item.button?.image = image
        item.button?.setAccessibilityLabel(Self.name)
        item.button?.target = target
        item.button?.action = action
        iconWidth = item.button?.fittingSize.width ?? 0
        drag = item.button.map { SpotMenuBarDrag(button: $0, onEnter: onDragEnter, onDrop: onDrop) }
        icon = makeIcon(model: model, toast: toast)
    }

    /// The item's frame on screen, or nil when macOS shows it nowhere, such as behind the notch.
    var frame: NSRect? {
        item.button?.window.flatMap { $0.occlusionState.contains(.visible) ? $0.frame : nil }
    }

    func contains(_ point: NSPoint) -> Bool {
        item.button?.window?.frame.contains(point) == true
    }

    /// Shows running work in place of the icon, or the icon again with no work.
    func show(work mark: TrayMark?) {
        guard let mark else {
            work?.remove()
            work = nil
            icon?.isHidden = false
            item.button?.toolTip = nil
            item.button?.setAccessibilityLabel(Self.name)
            item.length = iconWidth
            return
        }
        icon?.isHidden = true
        if let work { work.draw(mark) } else { work = MenuBarMarkItem(item: item, mark: mark) }
    }

    /// Moves the image of the item into a SwiftUI view of the same width.
    private func makeIcon(model: SpotsModel, toast: Toast?) -> MenuBarHost<SpotTrayIconView>? {
        guard let button = item.button, let image = button.image else { return nil }
        button.image = nil
        let host = MenuBarHost(rootView: SpotTrayIconView(model: model, image: image, toast: toast))
        host.frame = NSRect(x: 0, y: 0, width: iconWidth, height: button.bounds.height)
        host.autoresizingMask = [.width, .height]
        button.addSubview(host)
        return host
    }
}
