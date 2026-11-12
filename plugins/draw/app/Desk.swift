import AppKit
import SwiftUI

/// The app of the board window: the tabs of the open boards, the list of boards, and the canvas and bars of the board
/// that shows. A second open of Draw, such as from Openspot, asks this one to show its board in a tab.
@MainActor
final class Desk: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let tabs: Tabs
    private let lock: Lock
    private let drawer = Drawer()
    private var side: NSView?
    private var stripLeading: NSLayoutConstraint?
    private var latchLeading: CGFloat = 0
    /// How far down the window the middle of the window buttons lies, where the tab row lines up.
    private var middle: CGFloat = 26
    private var stage = NSView()
    var window: NSWindow!
    var canvas: Canvas!

    var studio: Studio { tabs.current }

    init(file: URL, lock: Lock) {
        tabs = Tabs(Studio(file: file))
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
        window.toolbar = NSToolbar(identifier: "Draw")
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Draw board")
        if window.frame.size == size { window.center() }
        mount()
        stageUp()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(asked(_:)), name: Desk.openName, object: nil)
    }

    /// Lays the parts that stay while tabs change: the stage of the board, the list of boards, its button and the tabs.
    private func mount() {
        let root = NSView()
        stage.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stage)
        let shelf = Shelf(folder: studio.file.deletingLastPathComponent())
        let side = bar(Sidebar(drawer: drawer, tabs: tabs, shelf: shelf, open: { [weak self] in self?.show($0) }, make: { [weak self] in self?.make() }, trash: { [weak self] in self?.trash($0) }), in: root)
        side.isHidden = !drawer.open
        self.side = side
        let latch = bar(Latch(drawer: drawer) { [weak self] in self?.toggleBoards(nil) }, in: root)
        let strip = bar(TabStrip(tabs: tabs, show: { [weak self] in self?.show($0.file) }, close: { [weak self] in self?.close($0) }, make: { [weak self] in self?.make() }, trash: { [weak self] in self?.trash($0) }), in: root)
        let lights = window.standardWindowButton(.zoomButton).map { $0.convert($0.bounds, to: nil) } ?? CGRect(x: 60, y: window.frame.height - 26, width: 14, height: 14)
        latchLeading = lights.maxX + 16
        middle = window.frame.height - lights.midY
        let stripLeading = strip.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: latchLeading + 46)
        self.stripLeading = stripLeading
        NSLayoutConstraint.activate([
            stage.leadingAnchor.constraint(equalTo: root.leadingAnchor), stage.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stage.topAnchor.constraint(equalTo: root.topAnchor), stage.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            side.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8), side.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            side.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
            latch.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: latchLeading),
            latch.centerYAnchor.constraint(equalTo: root.topAnchor, constant: middle),
            stripLeading, strip.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -236),
            strip.centerYAnchor.constraint(equalTo: root.topAnchor, constant: middle)
        ])
        window.contentView = root
    }

    /// Lays the canvas and the bars of the board that shows.
    private func stageUp() {
        stage.subviews.forEach { $0.removeFromSuperview() }
        let studio = studio
        studio.gone = { [weak self, weak studio] in
            guard let self, let studio else { return }
            self.close(studio)
        }
        canvas = Canvas(studio: studio)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(canvas)
        let canvas = canvas!
        let tools = bar(Toolbar(studio: studio, picture: { canvas.insertPicture(nil) }), in: stage)
        let corner = bar(Corner(studio: studio, zoom: { canvas.zoom(to: $0) }, fit: { canvas.fit() }), in: stage)
        let style = bar(StyleSlot(studio: studio), in: stage)
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: stage.leadingAnchor), canvas.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: stage.topAnchor), canvas.bottomAnchor.constraint(equalTo: stage.bottomAnchor),
            tools.centerXAnchor.constraint(equalTo: stage.centerXAnchor), tools.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: -14),
            corner.trailingAnchor.constraint(equalTo: stage.trailingAnchor, constant: -10), corner.centerYAnchor.constraint(equalTo: stage.topAnchor, constant: middle),
            style.trailingAnchor.constraint(equalTo: stage.trailingAnchor, constant: -14), style.topAnchor.constraint(equalTo: corner.bottomAnchor, constant: 10)
        ])
        window.title = studio.board.title
        window.makeFirstResponder(canvas)
        stage.layoutSubtreeIfNeeded()
        canvas.fit()
    }

    /// Shows a board in its tab, or in a new tab when it is not open.
    func show(_ file: URL) {
        guard file.standardizedFileURL != studio.file.standardizedFileURL else { return }
        canvas.endEditing()
        studio.save()
        withAnimation(.spring(duration: 0.3, bounce: 0.12)) { tabs.show(file) }
        stageUp()
    }

    /// Closes a board's tab, and Draw with the last one.
    func close(_ studio: Studio) {
        if studio === self.studio { canvas.endEditing() }
        if FileManager.default.fileExists(atPath: studio.file.path) { studio.save() }
        let shown = self.studio
        var closed = false
        withAnimation(.spring(duration: 0.3, bounce: 0.12)) { closed = tabs.close(studio) }
        guard closed else {
            NSApp.terminate(nil)
            return
        }
        if tabs.current !== shown { stageUp() }
    }

    /// Makes a new board beside the others and shows it in a new tab.
    func make() {
        guard let file = try? Shelf(folder: studio.file.deletingLastPathComponent()).make() else { return }
        show(file)
    }

    /// Slides the list of boards in or out, and moves the tabs beside it. The list leaves the window when it is out, so
    /// the canvas takes each press there.
    @objc func toggleBoards(_ sender: Any?) {
        let opening = !drawer.open
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            stripLeading?.animator().constant = opening ? 290 : latchLeading + 46
        }
        if opening {
            side?.isHidden = false
            DispatchQueue.main.async { [self] in
                withAnimation(.spring(duration: 0.35, bounce: 0.1)) { drawer.open = true }
            }
        } else {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { drawer.open = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [self] in
                if !drawer.open { side?.isHidden = true }
            }
        }
    }

    /// Moves a board, its picture and its images to the Trash, and closes its tab. With no other tab open, another board
    /// shows first, or a new one.
    func trash(_ file: URL) {
        let shelf = Shelf(folder: studio.file.deletingLastPathComponent())
        if let open = tabs.studio(for: file) {
            if tabs.studios.count == 1 {
                guard let next = shelf.entries.first(where: { $0.file.standardizedFileURL != file.standardizedFileURL })?.file ?? (try? shelf.make()) else { return }
                show(next)
            }
            close(open)
        }
        try? shelf.discard(file) { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
        drawer.changes += 1
    }

    @objc func trashBoard(_ sender: Any?) {
        trash(studio.file)
    }

    @objc func revealBoard(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([studio.file])
    }

    @objc func newBoard(_ sender: Any?) {
        make()
    }

    @objc func closeBoard(_ sender: Any?) {
        close(studio)
    }

    /// Shows the list of boards with the name of this board ready to change.
    @objc func renameBoard(_ sender: Any?) {
        if !drawer.open { toggleBoards(nil) }
        drawer.naming = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in drawer.naming = studio.file }
    }

    /// Floats a SwiftUI bar over the canvas at its own size.
    private func bar(_ content: some View, in root: NSView) -> NSView {
        let host = NSHostingView(rootView: content)
        host.safeAreaRegions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(host)
        return host
    }

    /// The message that another start of Draw sends with the path of the board to show.
    nonisolated static let openName = Notification.Name("dev.openspot.draw.open")

    @objc func asked(_ note: Notification) {
        guard let path = note.object as? String else { return }
        show(URL(fileURLWithPath: path))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        studio.reloadTitle()
    }

    func windowWillClose(_ notification: Notification) {
        canvas.endEditing()
        for studio in tabs.studios where FileManager.default.fileExists(atPath: studio.file.path) { studio.save() }
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        canvas.endEditing()
        for studio in tabs.studios where FileManager.default.fileExists(atPath: studio.file.path) { studio.save() }
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
            item("Rename Board…", #selector(Desk.renameBoard(_:)), "r"),
            item("Show in Finder", #selector(Desk.revealBoard(_:)), "r", [.command, .option]),
            .separator(),
            item("Move to Trash", #selector(Desk.trashBoard(_:)), "\u{8}"),
            .separator(),
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
            item("Close Tab", #selector(Desk.closeBoard(_:)), "w"),
            item("Close Window", #selector(NSWindow.performClose(_:)), "w", [.command, .shift])
        ])
        return main
    }
}

