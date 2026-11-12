import AppKit
import SwiftUI

/// The app of the board window: its canvas, its floating bars and its menu. It shows one board at a time, and a pick in
/// the list of boards shows another in the same window.
@MainActor
final class Desk: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private(set) var studio: Studio
    private var lock: Lock
    private let drawer = Drawer()
    var window: NSWindow!
    var canvas: Canvas!

    init(file: URL, lock: Lock) {
        studio = Studio(file: file)
        self.lock = lock
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = menu()
        NSApp.applicationIconImage = icon()
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: min(1280, screen.width * 0.85), height: min(860, screen.height * 0.85))
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Draw board")
        if window.frame.size == size { window.center() }
        mount()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Lays the canvas and the bars of the current board into the window.
    private func mount() {
        canvas = Canvas(studio: studio)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        let root = NSView()
        root.addSubview(canvas)
        let canvas = canvas!
        let shelf = Shelf(folder: studio.file.deletingLastPathComponent())
        let tools = bar(Toolbar(studio: studio, picture: { canvas.insertPicture(nil) }), in: root)
        let corner = bar(Corner(studio: studio, zoom: { canvas.zoom(to: $0) }, fit: { canvas.fit() }), in: root)
        let style = bar(StyleSlot(studio: studio), in: root)
        let side = bar(Sidebar(drawer: drawer, studio: studio, shelf: shelf, open: { [weak self] in self?.show($0) }, make: { [weak self] in self?.make() }), in: root)
        let toggle = bar(Knob(symbol: "sidebar.left", help: "Boards  ⌃⌘S", below: true) { [weak self] in self?.toggleBoards(nil) }, in: root)
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: root.leadingAnchor), canvas.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: root.topAnchor), canvas.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            side.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8), side.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            side.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
            toggle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 80), toggle.topAnchor.constraint(equalTo: root.topAnchor, constant: 4),
            tools.centerXAnchor.constraint(equalTo: root.centerXAnchor), tools.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            corner.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14), corner.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            style.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14), style.topAnchor.constraint(equalTo: root.topAnchor, constant: 52)
        ])
        window.contentView = root
        window.title = studio.board.title
        window.makeFirstResponder(canvas)
        canvas.layoutSubtreeIfNeeded()
        canvas.fit()
        DistributedNotificationCenter.default().removeObserver(self)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(front), name: Desk.showName, object: studio.file.path)
    }

    /// Shows another board in this window. A board that another window shows comes to the front there instead.
    func show(_ file: URL) {
        guard file.standardizedFileURL != studio.file.standardizedFileURL else { return }
        guard let next = Lock.claim(file) else {
            DistributedNotificationCenter.default().postNotificationName(Desk.showName, object: file.path, userInfo: nil, deliverImmediately: true)
            return
        }
        canvas.endEditing()
        studio.save()
        lock.release()
        lock = next
        studio = Studio(file: file)
        mount()
    }

    /// Makes a new board beside this one and shows it.
    func make() {
        guard let file = try? Shelf(folder: studio.file.deletingLastPathComponent()).make() else { return }
        show(file)
    }

    @objc func toggleBoards(_ sender: Any?) {
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) { drawer.open.toggle() }
    }

    @objc func newBoard(_ sender: Any?) {
        make()
    }

    /// Floats a SwiftUI bar over the canvas at its own size. A press where the bar draws nothing reaches the canvas.
    private func bar(_ content: some View, in root: NSView) -> NSView {
        let host = ClearHost(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(host)
        return host
    }

    nonisolated static let showName = Notification.Name("dev.openspot.draw.show")

    @objc func front() {
        studio.reloadTitle()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        studio.reloadTitle()
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
        add("File", [
            item("New Board", #selector(Desk.newBoard(_:)), "n"),
            item("Insert Image…", #selector(Canvas.insertPicture(_:)), "i", [.command, .shift])
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
            item("Show the Whole Board", #selector(Canvas.zoomToFit(_:)), "1", .shift),
            item("Show Boards", #selector(Desk.toggleBoards(_:)), "s", [.command, .control])
        ])
        add("Window", [
            item("Minimize", #selector(NSWindow.miniaturize(_:)), "m"),
            item("Close", #selector(NSWindow.performClose(_:)), "w")
        ])
        return main
    }
}

/// A hosting view that lets a press through where its SwiftUI content draws nothing.
final class ClearHost<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}
