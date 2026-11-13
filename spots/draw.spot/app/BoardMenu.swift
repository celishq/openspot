import AppKit
import SwiftUI

/// The menu of one board or of several picked ones: rename, show in Finder, and, past a line, delete in red, each with
/// its icon and its key.
struct BoardMenu {
    var count = 1
    let rename: () -> Void
    let reveal: () -> Void
    let trash: () -> Void

    var menu: NSMenu {
        let menu = NSMenu()
        if count == 1 {
            menu.addItem(Act("Rename", symbol: "pencil", key: "r", flags: .command, run: rename))
        }
        menu.addItem(Act("Show in Finder", symbol: "folder", key: "r", flags: [.command, .option], run: reveal))
        menu.addItem(.separator())
        let delete = Act(count == 1 ? "Delete" : "Delete \(count) Boards", symbol: "trash", key: "\u{8}", flags: .command, run: trash)
        delete.attributedTitle = NSAttributedString(string: delete.title, attributes: [.foregroundColor: NSColor.systemRed, .font: NSFont.menuFont(ofSize: 0)])
        delete.image = delete.image?.withSymbolConfiguration(.init(paletteColors: [.systemRed]))
        menu.addItem(delete)
        return menu
    }
}

/// A menu item that runs a closure.
final class Act: NSMenuItem {
    private let run: () -> Void

    init(_ title: String, symbol: String, key: String, flags: NSEvent.ModifierFlags, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        keyEquivalentModifierMask = flags
        target = self
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() {
        run()
    }
}

/// A spot over a SwiftUI view that opens an AppKit menu on a right-click or a Control-click, and lets each other press
/// through to the view.
struct MenuSpot: NSViewRepresentable {
    let menu: () -> NSMenu

    func makeNSView(context: Context) -> Spot {
        Spot()
    }

    func updateNSView(_ view: Spot, context: Context) {
        view.menu = nil
        view.build = menu
    }

    final class Spot: NSView {
        var build: () -> NSMenu = { NSMenu() }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            let asks = event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
            return asks ? super.hitTest(point) : nil
        }

        override func rightMouseDown(with event: NSEvent) {
            NSMenu.popUpContextMenu(build(), with: event, for: self)
        }

        override func mouseDown(with event: NSEvent) {
            NSMenu.popUpContextMenu(build(), with: event, for: self)
        }
    }
}
