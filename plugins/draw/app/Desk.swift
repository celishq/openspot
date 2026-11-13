import AppKit
import SwiftUI

/// The app of the board window: the tabs, the list of boards, and the canvas and bars of the board that shows, or the
/// start page on a New Tab. A second open of Draw, such as from Openspot, asks this one to show its board in a tab.
@MainActor
final class Desk: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let tabs: Tabs
    /// The folder of the boards.
    let folder: URL
    private let lock: Lock
    private let drawer = Drawer()
    private var side: NSView?
    private var stripLeading: NSLayoutConstraint?
    private var latchConstraint: NSLayoutConstraint?
    private var cornerLeading: NSLayoutConstraint?
    /// Where a bar beside the open list of boards starts.
    private static let besideList: CGFloat = 290

    /// How far down the content of a tab starts, under the title row and the row of tabs when it shows.
    private var top: CGFloat {
        middle + 26
    }
    private var latchLeading: CGFloat = 0
    /// How far down the window the middle of the window buttons lies, where the tab row lines up.
    private var middle: CGFloat = 26
    private var stage = NSView()
    var window: NSWindow!
    var canvas: Canvas?

    /// The board that shows, or nil on a New Tab.
    var studio: Studio? { tabs.studio }

    init(file: URL, lock: Lock) {
        tabs = Tabs(Studio(file: file))
        folder = file.deletingLastPathComponent()
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

    /// Lays the parts that stay while tabs change: the stage, the list of boards, its button and the tabs.
    private func mount() {
        let root = NSView()
        stage.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stage)
        let side = bar(Sidebar(drawer: drawer, tabs: tabs, shelf: Shelf(folder: folder), open: { [weak self] in self?.show($0) }, make: { [weak self] in self?.make(in: $0) },
                               makeFolder: { [weak self] in self?.makeFolder(in: $0) }, rename: { [weak self] in self?.rename($0, to: $1) }, trash: { [weak self] in self?.trash($0) },
                               move: { [weak self] in self?.move($0, into: $1) }), in: root)
        side.isHidden = !drawer.open
        self.side = side
        let latch = bar(Latch(drawer: drawer) { [weak self] in self?.toggleBoards(nil) }, in: root)
        let strip = bar(TabStrip(tabs: tabs, select: { [weak self] in self?.select($0) }, close: { [weak self] in self?.close(page: $0) }, trash: { [weak self] in self?.trash($0) }), in: root, stretches: true)
        let plus = bar(NewTabButton { [weak self] in self?.goHome(nil) }, in: root)
        let lights = window.standardWindowButton(.zoomButton).map { $0.convert($0.bounds, to: nil) } ?? CGRect(x: 60, y: window.frame.height - 26, width: 14, height: 14)
        latchLeading = lights.maxX + 16
        middle = window.frame.height - lights.midY
        let latchConstraint = latch.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: drawer.open ? 222 : latchLeading)
        self.latchConstraint = latchConstraint
        let stripLeading = strip.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: stripStart(open: drawer.open))
        self.stripLeading = stripLeading
        NSLayoutConstraint.activate([
            stage.leadingAnchor.constraint(equalTo: root.leadingAnchor), stage.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stage.topAnchor.constraint(equalTo: root.topAnchor), stage.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            side.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8), side.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            side.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
            latchConstraint,
            latch.centerYAnchor.constraint(equalTo: root.topAnchor, constant: middle),
            stripLeading, strip.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -58),
            strip.centerYAnchor.constraint(equalTo: root.topAnchor, constant: middle), strip.heightAnchor.constraint(equalToConstant: 30),
            plus.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            plus.centerYAnchor.constraint(equalTo: root.topAnchor, constant: middle)
        ])
        window.contentView = root
    }

    /// Where the tabs start: after the sidebar button or the open list, and after undo and redo when a board shows.
    private func stripStart(open: Bool) -> CGFloat {
        (open ? Desk.besideList : latchLeading + 56) + (studio == nil ? 0 : 96)
    }

    /// Lays the canvas and the bars of the board that shows, or the start page on a New Tab.
    private func stageUp() {
        stage.subviews.forEach { $0.removeFromSuperview() }
        stripLeading?.constant = stripStart(open: drawer.open)
        guard let studio else {
            canvas = nil
            let home = bar(Home(drawer: drawer, shelf: Shelf(folder: folder), open: { [weak self] in self?.show($0) }, make: { [weak self] in self?.make(in: nil) }, trash: { [weak self] in self?.trash($0) }, rename: { [weak self] file in
                self?.show(file)
                self?.renameBoard(nil)
            }), in: stage)
            NSLayoutConstraint.activate([
                home.leadingAnchor.constraint(equalTo: stage.leadingAnchor), home.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
                home.topAnchor.constraint(equalTo: stage.topAnchor, constant: top), home.bottomAnchor.constraint(equalTo: stage.bottomAnchor)
            ])
            window.title = "New Tab"
            return
        }
        studio.gone = { [weak self, weak studio] in
            guard let self, let studio, let page = self.tabs.page(of: studio) else { return }
            self.close(page: page)
        }
        let canvas = Canvas(studio: studio)
        self.canvas = canvas
        canvas.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(canvas)
        let tools = bar(Toolbar(studio: studio, picture: { canvas.insertPicture(nil) }), in: stage)
        let corner = bar(Corner(studio: studio), in: stage)
        let style = bar(StyleSlot(studio: studio), in: stage)
        let cornerLeading = corner.leadingAnchor.constraint(equalTo: stage.leadingAnchor, constant: drawer.open ? Desk.besideList : latchLeading + 56)
        self.cornerLeading = cornerLeading
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: stage.leadingAnchor), canvas.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: stage.topAnchor), canvas.bottomAnchor.constraint(equalTo: stage.bottomAnchor),
            tools.centerXAnchor.constraint(equalTo: stage.centerXAnchor), tools.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: -14),
            cornerLeading, corner.centerYAnchor.constraint(equalTo: stage.topAnchor, constant: middle),
            style.trailingAnchor.constraint(equalTo: stage.trailingAnchor, constant: -14), style.topAnchor.constraint(equalTo: stage.topAnchor, constant: top)
        ])
        window.title = studio.board.title
        window.makeFirstResponder(canvas)
        stage.layoutSubtreeIfNeeded()
        canvas.fit()
    }

    /// Saves the board that shows before another tab shows.
    private func leave() {
        canvas?.endEditing()
        studio?.save()
    }

    /// Shows a board in its tab, or in the New Tab that shows, or in a new tab.
    func show(_ file: URL) {
        guard !tabs.shows(file) else { return }
        leave()
        withAnimation(.spring(duration: 0.3, bounce: 0.12)) { tabs.show(file) }
        stageUp()
    }

    func select(_ id: UUID) {
        guard id != tabs.currentID else { return }
        leave()
        tabs.select(id)
        stageUp()
    }

    /// Closes a tab. The last tab becomes a New Tab.
    func close(page id: UUID) {
        let shown = tabs.currentID
        if let closing = tabs.pages.first(where: { $0.id == id })?.studio {
            if id == shown { canvas?.endEditing() }
            if FileManager.default.fileExists(atPath: closing.file.path) { closing.save() }
        }
        withAnimation(.spring(duration: 0.3, bounce: 0.12)) { tabs.close(id) }
        if tabs.currentID != shown || id == shown { stageUp() }
    }

    /// Makes a new board in a folder, or at the top, and shows it in the New Tab that shows or in a new tab.
    func make(in place: URL?) {
        guard let file = try? Shelf(folder: folder).make(in: place) else { return }
        if let place { drawer.expanded.insert(place.path) }
        drawer.changes += 1
        show(file)
    }

    /// Makes a new folder in a folder, or at the top, with its name ready to change.
    func makeFolder(in place: URL?) {
        guard let made = try? Shelf(folder: folder).makeFolder(in: place) else { return }
        if let place { drawer.expanded.insert(place.path) }
        if !drawer.open { toggleBoards(nil) }
        drawer.changes += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            drawer.picking.reset(to: made)
            drawer.naming = made
        }
    }

    /// Renames a board, or a folder, and shows the open boards inside a renamed folder from where they now are.
    func rename(_ url: URL, to name: String) {
        if !Shelf.isFolder(url) {
            if let open = tabs.studio(for: url) { open.rename(name) } else { try? Shelf(folder: folder).rename(url, to: name) }
            return
        }
        relocate(url) { try Shelf(folder: folder).rename(url, to: name) }
    }

    /// Moves boards and folders into a folder, and keeps their open tabs.
    func move(_ urls: [URL], into target: URL) {
        let inside = tabs.studios.filter { studio in urls.contains { studio.file.standardizedFileURL == $0.standardizedFileURL || studio.file.path.hasPrefix($0.path + "/") } }
        if let shown = studio, inside.contains(where: { $0 === shown }) { canvas?.endEditing() }
        inside.forEach { $0.save() }
        let shelf = Shelf(folder: folder)
        let moved = urls.map { (try? shelf.move($0, into: target)) ?? $0 }
        let current = tabs.currentID
        var changed = false
        for (old, new) in zip(urls, moved) where old != new {
            for studio in inside where studio.file == old || studio.file.path.hasPrefix(old.path + "/") {
                guard let page = tabs.page(of: studio) else { continue }
                tabs.replace(page, with: URL(fileURLWithPath: new.path + studio.file.path.dropFirst(old.path.count)))
                if page == current { changed = true }
            }
        }
        if target.path != folder.path { drawer.expanded.insert(target.path) }
        if changed { stageUp() }
        drawer.changes += 1
    }

    /// Moves a board or a folder with `change`, and shows each open board from where it now is.
    private func relocate(_ url: URL, change: () throws -> URL) {
        let inside = tabs.studios.filter { $0.file.standardizedFileURL == url.standardizedFileURL || $0.file.path.hasPrefix(url.path + "/") }
        let shown = studio.map { shown in inside.contains { $0 === shown } } ?? false
        if shown { canvas?.endEditing() }
        inside.forEach { $0.save() }
        guard let moved = try? change(), moved != url else { return }
        if drawer.expanded.remove(url.path) != nil { drawer.expanded.insert(moved.path) }
        let current = tabs.currentID
        for studio in inside {
            let next = URL(fileURLWithPath: moved.path + studio.file.path.dropFirst(url.path.count))
            guard let page = tabs.page(of: studio) else { continue }
            tabs.replace(page, with: next)
        }
        if shown || tabs.currentID != current { stageUp() }
        drawer.picking.clear()
        drawer.changes += 1
    }

    /// Slides the list of boards in or out, and moves the tabs beside it. The list leaves the window when it is out, so
    /// the canvas takes each press there.
    @objc func toggleBoards(_ sender: Any?) {
        let opening = !drawer.open
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            stripLeading?.animator().constant = stripStart(open: opening)
            latchConstraint?.animator().constant = opening ? 222 : latchLeading
            cornerLeading?.animator().constant = opening ? Desk.besideList : latchLeading + 56
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

    /// Moves boards, their pictures and their images to the Trash, and closes their tabs. A folder goes only after the
    /// person says yes, since it takes its boards with it.
    func trash(_ files: [URL]) {
        let folders = files.filter(Shelf.isFolder)
        if !folders.isEmpty {
            let boards = folders.reduce(0) { $0 + Shelf(folder: $1).entries.count }
            let alert = NSAlert()
            alert.messageText = folders.count == 1 ? "Delete “\(folders[0].lastPathComponent)”?" : "Delete \(folders.count) folders?"
            alert.informativeText = boards == 0 ? "The folder moves to the Trash." : "The folder and the \(boards) \(boards == 1 ? "board" : "boards") in it move to the Trash."
            alert.addButton(withTitle: "Delete").hasDestructiveAction = true
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: window) { [weak self] answer in
                guard answer == .alertFirstButtonReturn else { return }
                MainActor.assumeIsolated { self?.discard(files) }
            }
            return
        }
        discard(files)
    }

    /// Moves boards and folders to the Trash and closes their tabs.
    private func discard(_ files: [URL]) {
        for file in files {
            for open in tabs.studios where open.file.standardizedFileURL == file.standardizedFileURL || open.file.path.hasPrefix(file.path + "/") {
                if let page = tabs.page(of: open) { close(page: page) }
            }
        }
        let shelf = Shelf(folder: folder)
        for file in files {
            try? shelf.discard(file) { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
        }
        drawer.picking.clear()
        drawer.changes += 1
    }

    func trash(_ file: URL) {
        trash([file])
    }

    /// Trashes the boards picked in the list or on the start page while it takes the keys, or else the board that shows.
    @objc func trashBoard(_ sender: Any?) {
        if drawer.focused, !drawer.picking.picked.isEmpty {
            trash(Array(drawer.picking.picked))
        } else if let studio {
            trash(studio.file)
        }
    }

    @objc func revealBoard(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([studio?.file ?? folder])
    }

    @objc func newBoard(_ sender: Any?) {
        make(in: drawer.focused ? drawer.picking.focus.map(Shelf(folder: folder).place(for:)) : nil)
    }

    @objc func newFolder(_ sender: Any?) {
        makeFolder(in: drawer.focused ? drawer.picking.focus.map(Shelf(folder: folder).place(for:)) : nil)
    }

    /// Adds a New Tab with the start page of all boards.
    @objc func goHome(_ sender: Any?) {
        leave()
        withAnimation(.spring(duration: 0.3, bounce: 0.12)) { tabs.openStart() }
        stageUp()
    }

    @objc func closeBoard(_ sender: Any?) {
        close(page: tabs.currentID)
    }

    /// Puts the caret in the search field: the start page's, or else the list's, which slides in.
    @objc func findBoards(_ sender: Any?) {
        if !tabs.home, !drawer.open { toggleBoards(nil) }
        drawer.searching = false
        DispatchQueue.main.async { [self] in drawer.searching = true }
    }

    /// Shows the list of boards with the name of this board ready to change.
    @objc func renameBoard(_ sender: Any?) {
        guard let file = studio?.file else { return }
        if !drawer.open { toggleBoards(nil) }
        drawer.naming = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in drawer.naming = file }
    }

    /// Floats a SwiftUI bar over the canvas at its own size, or at the size its constraints give when it `stretches`.
    private func bar(_ content: some View, in root: NSView, stretches: Bool = false) -> NSView {
        let host = NSHostingView(rootView: content)
        if stretches { host.sizingOptions = [] }
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
        studio?.reloadTitle()
    }

    func windowWillClose(_ notification: Notification) {
        canvas?.endEditing()
        for studio in tabs.studios where FileManager.default.fileExists(atPath: studio.file.path) { studio.save() }
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        canvas?.endEditing()
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
            item("New Folder", #selector(Desk.newFolder(_:)), "n", [.command, .shift]),
            item("New Tab", #selector(Desk.goHome(_:)), "t"),
            item("Rename Board…", #selector(Desk.renameBoard(_:)), "r"),
            item("Show in Finder", #selector(Desk.revealBoard(_:)), "r", [.command, .option]),
            item("Find Board…", #selector(Desk.findBoards(_:)), "f"),
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

