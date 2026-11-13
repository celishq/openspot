import SwiftUI

/// The row of tabs under the title row, as Safari draws it: equal tabs on a grey track, the current one raised in white.
/// It shows only with two tabs or more. A tab grows in when it opens and folds away when it closes.
struct TabStrip: View {
    @ObservedObject var tabs: Tabs
    let select: (UUID) -> Void
    let close: (UUID) -> Void
    let trash: (URL) -> Void

    var body: some View {
        if tabs.pages.count > 1 {
            HStack(spacing: 0) {
                ForEach(Array(tabs.pages.enumerated()), id: \.element.id) { index, page in
                    let current = page.id == tabs.currentID
                    let next = index + 1 < tabs.pages.count ? tabs.pages[index + 1].id : nil
                    TabChip(page: page, current: current, select: { select(page.id) }, close: { close(page.id) }, trash: { page.studio.map { trash($0.file) } })
                        .overlay(alignment: .trailing) {
                            if !current, next != tabs.currentID, next != nil {
                                Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1, height: 14)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.4, anchor: .leading).combined(with: .opacity),
                            removal: .scale(scale: 0.2, anchor: .leading).combined(with: .opacity)
                        ))
                }
            }
            .padding(2)
            .background(Color.primary.opacity(0.07), in: Capsule())
            .frame(height: 32)
            .transition(.opacity)
        }
    }
}

/// The + at the top right that adds a New Tab with the start page.
struct NewTabButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 30)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .tip("New tab  ⌘T", below: true)
    }
}

/// One tab: the board's name, centred, which a double-click renames, or New Tab; and, while the pointer rests on it, a
/// close button on the left.
struct TabChip: View {
    let page: Tabs.Page
    let current: Bool
    let select: () -> Void
    let close: () -> Void
    let trash: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: page.studio == nil ? "square.grid.2x2" : "doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            if let studio = page.studio {
                TabTitle(studio: studio)
            } else {
                Text("New Tab").lineLimit(1)
            }
        }
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(current ? Color.primary : Color.secondary)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
        .overlay(alignment: .leading) {
            if hovering {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.06), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
                .help("Close tab  ⌘W")
            }
        }
        .background {
            Capsule()
                .fill(current ? Color.white : Color.primary.opacity(hovering ? 0.05 : 0))
                .shadow(color: .black.opacity(current ? 0.12 : 0), radius: 3, y: 1)
        }
        .contentShape(Rectangle())
        .onHover { inside in withAnimation(.easeOut(duration: 0.12)) { hovering = inside } }
        .onTapGesture {
            if (NSApp.currentEvent?.clickCount ?? 1) > 1, page.studio != nil {
                NotificationCenter.default.post(name: TabTitle.renameName, object: page.studio)
            } else {
                select()
            }
        }
        .overlay {
            if let studio = page.studio {
                MenuSpot {
                    BoardMenu(rename: { NotificationCenter.default.post(name: TabTitle.renameName, object: studio) },
                              reveal: { NSWorkspace.shared.activateFileViewerSelecting([studio.file]) }, trash: trash).menu
                }
            }
        }
    }
}

/// The title of a board's tab, which turns into a field to rename it.
struct TabTitle: View {
    @ObservedObject var studio: Studio
    @State private var naming = false
    @State private var name = ""
    @FocusState private var typing: Bool

    /// Asks the tab of the board in `object` to rename it.
    static let renameName = Notification.Name("dev.openspot.draw.rename-tab")

    var body: some View {
        Group {
            if naming {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .focused($typing)
                    .onSubmit { typing = false }
                    .onChange(of: typing) { _, now in
                        if !now {
                            studio.rename(name)
                            naming = false
                        }
                    }
            } else {
                Text(studio.board.title).lineLimit(1).truncationMode(.tail)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.renameName)) { note in
            guard note.object as AnyObject? === studio else { return }
            name = studio.board.title
            naming = true
            typing = true
        }
    }
}
