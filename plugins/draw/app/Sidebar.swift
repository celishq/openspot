import SwiftUI

/// The list of boards that slides in from the left: a search field, buttons for a new board and a new folder, and the
/// tree of folders and boards. A click picks, a double-click or Return opens a board or a folder, and a new board or
/// folder goes where the pick is, as in a code editor.
struct Sidebar: View {
    @ObservedObject var drawer: Drawer
    @ObservedObject var tabs: Tabs
    let shelf: Shelf
    let open: (URL) -> Void
    let make: (URL?) -> Void
    let makeFolder: (URL?) -> Void
    let rename: (URL, String) -> Void
    let trash: ([URL]) -> Void
    @State private var tree: [Shelf.Node] = []
    @State private var name = ""
    @FocusState private var typing: Bool
    @FocusState private var listening: Bool
    @State private var frames: [URL: CGRect] = [:]

    /// The rows that show, each with how deep it lies: the open folders' tree, or the boards that a search finds.
    private var rows: [(node: Shelf.Node, depth: Int)] {
        if !drawer.query.trimmingCharacters(in: .whitespaces).isEmpty {
            return shelf.entries(matching: drawer.query).map { (Shelf.Node(url: $0.file, title: $0.title, edited: $0.edited, isFolder: false), 0) }
        }
        func walk(_ nodes: [Shelf.Node], _ depth: Int) -> [(node: Shelf.Node, depth: Int)] {
            nodes.flatMap { node in [(node, depth)] + (node.isFolder && drawer.expanded.contains(node.url) ? walk(node.children, depth + 1) : []) }
        }
        return walk(tree, 0)
    }

    private var order: [URL] {
        rows.map(\.node.url)
    }

    /// Where a new board or folder goes: by the row that the pick last landed on.
    private var place: URL? {
        drawer.picking.focus.map(shelf.place(for:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Search(drawer: drawer, takesFocus: false)
                    .padding(.trailing, 4)
                Knob(symbol: "doc.badge.plus", help: "New board  ⌘N", below: true) { make(place) }
                Knob(symbol: "folder.badge.plus", help: "New folder  ⇧⌘N", below: true) { makeFolder(place) }
            }
            .frame(height: 34)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(rows, id: \.node.url) { row in
                        line(row.node, depth: row.depth)
                            .background(GeometryReader { place in
                                Color.clear.preference(key: RowFrames.self, value: [row.node.url: place.frame(in: .named("list"))])
                            })
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 400, alignment: .top)
                .contentShape(Rectangle())
                .onTapGesture {
                    drawer.picking.clear()
                    listening = true
                }
                .coordinateSpace(name: "list")
                .onPreferenceChange(RowFrames.self) { frames = $0 }
                .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("list"))
                    .onChanged { drag in
                        guard let start = row(at: drag.startLocation), let end = row(at: drag.location) else { return }
                        drawer.picking.sweep(from: start, to: end, in: order, adding: NSEvent.modifierFlags.contains(.command))
                        listening = true
                    }
                    .onEnded { _ in drawer.picking.endSweep() })
            }
            .focusable()
            .focusEffectDisabled()
            .focused($listening)
            .onChange(of: listening) { _, now in drawer.focused = now }
            .onKeyPress(.upArrow, phases: .down) { press in walk(-1, extend: press.modifiers.contains(.shift)) }
            .onKeyPress(.downArrow, phases: .down) { press in walk(1, extend: press.modifiers.contains(.shift)) }
            .onKeyPress(.rightArrow) { fold(open: true) }
            .onKeyPress(.leftArrow) { fold(open: false) }
            .onKeyPress(.return) {
                let picked = order.filter(drawer.picking.picked.contains)
                guard !picked.isEmpty else { return .ignored }
                picked.forEach(activate)
                return .handled
            }
            .onKeyPress(.delete) {
                guard !drawer.picking.picked.isEmpty else { return .ignored }
                trash(Array(drawer.picking.picked))
                return .handled
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 58)
        .padding(.bottom, 10)
        .frame(width: 270)
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(Raised())
        .offset(x: drawer.open ? 0 : -300)
        .onAppear(perform: reload)
        .onChange(of: drawer.open) { _, open in if open { reload() } }
        .onReceive(tabs.$currentID) { _ in reload() }
        .onChange(of: drawer.changes) { _, _ in reload() }
        .onChange(of: drawer.naming) { _, url in
            if let url, let node = rows.first(where: { $0.node.url == url })?.node { startNaming(node) }
        }
    }

    private func reload() {
        tree = shelf.tree
    }

    /// Opens a board, or opens or closes a folder.
    private func activate(_ url: URL) {
        if Shelf.isFolder(url) {
            withAnimation(.easeOut(duration: 0.15)) {
                if drawer.expanded.contains(url) { drawer.expanded.remove(url) } else { drawer.expanded.insert(url) }
            }
        } else {
            open(url)
        }
    }

    /// Opens or closes the picked folder with the right and left arrows.
    private func fold(open: Bool) -> KeyPress.Result {
        guard let focus = drawer.picking.focus, Shelf.isFolder(focus) else { return .ignored }
        withAnimation(.easeOut(duration: 0.15)) {
            if open { drawer.expanded.insert(focus) } else { drawer.expanded.remove(focus) }
        }
        return .handled
    }

    /// Moves the pick with an arrow key. Return opens what it picks.
    private func walk(_ offset: Int, extend: Bool) -> KeyPress.Result {
        guard drawer.picking.step(offset, in: order, extend: extend) != nil else { return .ignored }
        return .handled
    }

    /// The row that lies under a point of the list.
    private func row(at point: CGPoint) -> URL? {
        frames.first { $0.value.insetBy(dx: -2, dy: -1).contains(CGPoint(x: $0.value.midX, y: point.y)) }?.key
    }

    /// Picks a row on a click: alone, with Command added or dropped, or with Shift the run to it.
    private func click(_ node: Shelf.Node) {
        let flags = NSEvent.modifierFlags
        let mode: Picking.Mode = flags.contains(.command) ? .toggle : flags.contains(.shift) ? .range : .only
        drawer.picking.click(node.url, in: order, mode: mode)
        listening = true
    }

    /// The menu of a row: for each picked row when the row is one of several picked, or else for the row alone.
    private func menu(for node: Shelf.Node) -> NSMenu {
        if !drawer.picking.picked.contains(node.url) { drawer.picking.click(node.url, in: order, mode: .only) }
        let urls = Array(drawer.picking.picked)
        return BoardMenu(count: urls.count, rename: { startNaming(node) }, reveal: { NSWorkspace.shared.activateFileViewerSelecting(urls) }, trash: { trash(urls) }).menu
    }

    private func line(_ node: Shelf.Node, depth: Int) -> some View {
        let picked = drawer.picking.picked.contains(node.url)
        let shown = tabs.shows(node.url)
        return HStack(spacing: 8) {
            if node.isFolder {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(drawer.expanded.contains(node.url) ? 90 : 0))
                    .frame(width: 14)
                    .contentShape(Rectangle())
                    .onTapGesture { activate(node.url) }
                Image(systemName: drawer.expanded.contains(node.url) ? "folder.fill" : "folder")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)
            } else {
                Group {
                    if let picture = NSImage(contentsOf: node.picture) {
                        Image(nsImage: picture).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.white
                    }
                }
                .frame(width: 44, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
            }
            VStack(alignment: .leading, spacing: 1) {
                if drawer.naming == node.url {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .focused($typing)
                        .onSubmit { finish(node) }
                        .onChange(of: typing) { _, now in if !now { finish(node) } }
                } else {
                    Text(node.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                }
                if !node.isFolder {
                    Text(node.edited.formatted(.relative(presentation: .named)).capitalized(with: nil))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(depth) * 16)
        .padding(6)
        .frame(minHeight: node.isFolder ? 32 : 44)
        .background(picked ? Color.accentColor.opacity(drawer.focused ? 0.2 : 0.12) : Color.primary.opacity(shown ? 0.05 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            guard drawer.naming != node.url else { return }
            if (NSApp.currentEvent?.clickCount ?? 1) > 1 { activate(node.url) } else { click(node) }
        }
        .overlay(MenuSpot { menu(for: node) })
    }

    private func startNaming(_ node: Shelf.Node) {
        name = node.title
        drawer.naming = node.url
        typing = true
    }

    private func finish(_ node: Shelf.Node) {
        guard drawer.naming == node.url else { return }
        drawer.naming = nil
        rename(node.url, name)
        reload()
    }
}
