import SwiftUI

/// The start page with no tab open: a search field over a grid of cards, one for each board and one for a new board.
/// A click opens a board in a tab, and a right-click gives the menu of a board. The search field keeps its height
/// whatever a search finds, and the page moves aside for the list of boards.
struct Home: View {
    @ObservedObject var drawer: Drawer
    let shelf: Shelf
    let open: (URL) -> Void
    let make: () -> Void
    let trash: ([URL]) -> Void
    let rename: (URL) -> Void
    @State private var entries: [Shelf.Entry] = []
    @State private var width: CGFloat = 900
    @State private var height: CGFloat = 600

    /// The width of a card.
    static let card: CGFloat = 220

    /// As many columns as fit, and no more than the cards, so a few cards sit in the middle.
    private var columns: Int {
        let room = width - (drawer.open ? 340 : 80)
        let fit = max(1, Int((room + 20) / (Home.card + 20)))
        return max(1, min(fit, entries.count + (drawer.query.isEmpty ? 1 : 0), 5))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Search(drawer: drawer, wide: true)
                    .frame(maxWidth: 460)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(Home.card), spacing: 20), count: columns), spacing: 24) {
                    if drawer.query.isEmpty {
                        Button(action: make) {
                            VStack(spacing: 8) {
                                Lifted {
                                    Image(systemName: "plus").font(.system(size: 26, weight: .regular)).foregroundStyle(.secondary)
                                }
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
            }
            .padding(.top, max(24, height * 0.18))
            .padding(.leading, drawer.open ? 300 : 40)
            .padding(.trailing, 40)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(GeometryReader { place in
            Color.clear
                .onAppear {
                    width = place.size.width
                    height = place.size.height
                }
                .onChange(of: place.size) { _, now in
                    width = now.width
                    height = now.height
                }
        })
        .onAppear(perform: reload)
        .onChange(of: drawer.query) { _, _ in reload() }
        .onChange(of: drawer.changes) { _, _ in reload() }
    }

    /// The boards that a search finds, or else the seven newest, so the page holds eight cards with New board.
    private func reload() {
        let found = shelf.entries(matching: drawer.query)
        entries = drawer.query.trimmingCharacters(in: .whitespaces).isEmpty ? Array(found.prefix(7)) : found
    }
}

/// One board on the start page: its picture on a raised card, its title and when it changed. The card lifts and tilts
/// toward the pointer while it rests on it.
struct Card: View {
    let entry: Shelf.Entry
    let open: () -> Void
    let menu: () -> NSMenu

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Lifted {
                if let picture = NSImage(contentsOf: entry.picture) {
                    Image(nsImage: picture).resizable().aspectRatio(contentMode: .fit).padding(6)
                }
            }
            Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
            Text(entry.edited.formatted(.relative(presentation: .named)).capitalized(with: nil))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .overlay(MenuSpot(menu: menu))
    }
}

/// A raised white card of the start page, with one even edge and layered shadows, that lifts and tilts toward the
/// pointer.
struct Lifted<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var tilt = CGSize.zero
    @State private var hovering = false

    var body: some View {
        GeometryReader { place in
            ZStack {
                Color.white
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(hovering ? 0.1 : 0.07), lineWidth: 1))
            .shadow(color: .black.opacity(hovering ? 0.14 : 0.07), radius: hovering ? 18 : 10, y: hovering ? 12 : 5)
            .rotation3DEffect(.degrees(Double(tilt.height) * 6), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(tilt.width) * -6), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(hovering ? 1.025 : 1)
            .offset(y: hovering ? -3 : 0)
            .onContinuousHover { phase in
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    switch phase {
                    case .active(let point):
                        hovering = true
                        tilt = CGSize(width: point.x / max(place.size.width, 1) - 0.5, height: point.y / max(place.size.height, 1) - 0.5)
                    case .ended:
                        hovering = false
                        tilt = .zero
                    }
                }
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
    }
}
