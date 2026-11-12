import AppKit
import OpenspotCore

/// The menu of a spot of the store, shown at the pointer: its choices in parts that lines divide, with the state it has
/// checked.
@MainActor
enum SpotStoreMenu {
    static func show(_ parts: [[SpotDock.Choice]], choose: @escaping (SpotDock.Action) -> Void) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, part) in parts.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for choice in part {
                let pick = Pick { choose(choice.action) }
                let item = NSMenuItem(title: choice.title, action: #selector(Pick.fire), keyEquivalent: "")
                item.target = pick
                item.representedObject = pick
                item.state = choice.isChecked ? .on : .off
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// The act of one menu item, which the item keeps alive.
    private final class Pick: NSObject {
        let act: () -> Void

        init(_ act: @escaping () -> Void) {
            self.act = act
        }

        @objc func fire(_ sender: Any?) {
            act()
        }
    }
}
