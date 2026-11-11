import AppKit
import SwiftUI

/// The app of one board: its window, its canvas, its floating bars and its menu.
@MainActor
final class Desk: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let studio: Studio
    var window: NSWindow!
    var canvas: Canvas!

    init(file: URL) {
        studio = Studio(file: file)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = menu()
        NSApp.applicationIconImage = icon()
        canvas = Canvas(studio: studio)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        let root = NSView()
        root.addSubview(canvas)
        let canvas = canvas!
        let tools = bar(Toolbar(studio: studio), in: root)
        let corner = bar(Corner(studio: studio, zoom: { canvas.zoom(to: $0) }, fit: { canvas.fit() }), in: root)
        let style = bar(StyleSlot(studio: studio), in: root)
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: root.leadingAnchor), canvas.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: root.topAnchor), canvas.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            tools.centerXAnchor.constraint(equalTo: root.centerXAnchor), tools.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            corner.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14), corner.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            style.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14), style.topAnchor.constraint(equalTo: root.topAnchor, constant: 40)
        ])
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: min(1280, screen.width * 0.85), height: min(860, screen.height * 0.85))
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.title = studio.board.title
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.contentView = root
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Draw board")
        if window.frame.size == size { window.center() }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
        canvas.layoutSubtreeIfNeeded()
        canvas.fit()
        NSApp.activate()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(show), name: Desk.showName, object: studio.file.path)
    }

    /// Floats a SwiftUI bar over the canvas at its own size.
    private func bar(_ content: some View, in root: NSView) -> NSView {
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(host)
        return host
    }

    nonisolated static let showName = Notification.Name("dev.openspot.draw.show")

    @objc func show() {
        studio.reloadTitle()
        window.title = studio.board.title
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        studio.reloadTitle()
        window.title = studio.board.title
    }

    func windowWillClose(_ notification: Notification) {
        canvas.endEditing()
        studio.save()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        canvas.endEditing()
        if FileManager.default.fileExists(atPath: studio.file.path) { studio.save() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func icon() -> NSImage {
        NSImage(size: CGSize(width: 256, height: 256), flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24), xRadius: 50, yRadius: 50).fill()
            let config = NSImage.SymbolConfiguration(pointSize: 120, weight: .semibold).applying(.init(paletteColors: [.controlAccentColor]))
            if let symbol = NSImage(systemSymbolName: "scribble.variable", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let size = symbol.size
                symbol.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
            }
            return true
        }
    }

    private func menu() -> NSMenu {
        let main = NSMenu()
        func add(_ title: String, _ items: [NSMenuItem]) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            item.submenu = menu
            main.addItem(item)
        }
        func item(_ title: String, _ action: Selector, _ key: String, _ flags: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = flags
            return item
        }
        add("Draw", [
            item("Hide Draw", #selector(NSApplication.hide(_:)), "h"),
            .separator(),
            item("Quit Draw", #selector(NSApplication.terminate(_:)), "q")
        ])
        add("Edit", [
            item("Undo", #selector(Canvas.undo(_:)), "z"),
            item("Redo", #selector(Canvas.redo(_:)), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(Canvas.cut(_:)), "x"),
            item("Copy", #selector(Canvas.copy(_:)), "c"),
            item("Paste", #selector(Canvas.paste(_:)), "v"),
            item("Duplicate", #selector(Canvas.duplicate(_:)), "d"),
            item("Delete", #selector(Canvas.delete(_:)), ""),
            item("Select All", #selector(Canvas.selectAll(_:)), "a")
        ])
        add("View", [
            item("Zoom In", #selector(Canvas.zoomIn(_:)), "="),
            item("Zoom Out", #selector(Canvas.zoomOut(_:)), "-"),
            item("Actual Size", #selector(Canvas.actualSize(_:)), "0"),
            item("Show the Whole Board", #selector(Canvas.zoomToFit(_:)), "1", .shift)
        ])
        add("Window", [
            item("Minimize", #selector(NSWindow.miniaturize(_:)), "m"),
            item("Close", #selector(NSWindow.performClose(_:)), "w")
        ])
        return main
    }
}
