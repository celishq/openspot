import SwiftUI

/// The start page with no tab open: a search field over a grid of cards, one for each board and one for a new board.
/// A click opens a board in a tab, and a right-click gives the menu of a board. It moves aside for the list of boards.
struct Home: View {
    @ObservedObject var drawer: Drawer
    let shelf: Shelf
    let open: (URL) -> Void
    let make: () -> Void
    let trash: ([URL]) -> Void
    let rename: (URL) -> Void
    @State private var entries: [Shelf.Entry] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Search(drawer: drawer, wide: true)
                    .frame(maxWidth: 460)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 20)], spacing: 22) {
                    if drawer.query.isEmpty {
                        Button(action: make) {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                    .overlay(Image(systemName: "plus").font(.system(size: 24, weight: .medium)).foregroundStyle(.secondary))
                                    .aspectRatio(1.5, contentMode: .fit)
                                Text("New board").font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading)
                                Text(" ").font(.system(size: 11))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(entries) { entry in
                        Card(entry: entry, open: { open(entry.file) }, menu: {
                            BoardMenu(rename: { rename(entry.file) }, reveal: { NSWorkspace.shared.activateFileViewerSelecting([entry.file]) }, trash: { trash([entry.file]) }).menu
                        })
                    }
                }
                .frame(maxWidth: 1100)
            }
            .padding(.leading, drawer.open ? 300 : 40)
            .padding(.trailing, 40)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: reload)
        .onChange(of: drawer.query) { _, _ in reload() }
        .onChange(of: drawer.changes) { _, _ in reload() }
    }

    private func reload() {
        entries = shelf.entries(matching: drawer.query)
    }
}

/// One board on the start page: its picture, its title and when it changed.
struct Card: View {
    let entry: Shelf.Entry
    let open: () -> Void
    let menu: () -> NSMenu
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let picture = NSImage(contentsOf: entry.picture) {
                    Image(nsImage: picture).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Color.white
                }
            }
            .aspectRatio(1.5, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(hovering ? 0.25 : 0.1)))
            .shadow(color: .black.opacity(hovering ? 0.12 : 0.05), radius: hovering ? 10 : 4, y: 2)
            Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
            Text(entry.edited.formatted(.relative(presentation: .named)).capitalized(with: nil))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onHover { inside in withAnimation(.easeOut(duration: 0.15)) { hovering = inside } }
        .onTapGesture(perform: open)
        .overlay(MenuSpot(menu: menu))
    }
}
