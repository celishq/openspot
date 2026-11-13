import SwiftUI

/// The tabs beside the window buttons, and a + that adds a New Tab with the start page. A tab grows in when it opens and
/// folds away when it closes.
struct TabStrip: View {
    @ObservedObject var tabs: Tabs
    let select: (UUID) -> Void
    let close: (UUID) -> Void
    let home: () -> Void
    let trash: (URL) -> Void
    @State private var adding = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.pages) { page in
                TabChip(page: page, current: page.id == tabs.currentID, closes: tabs.pages.count > 1 || page.studio != nil,
                        select: { select(page.id) }, close: { close(page.id) }, trash: { page.studio.map { trash($0.file) } })
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4, anchor: .leading).combined(with: .opacity),
                        removal: .scale(scale: 0.2, anchor: .leading).combined(with: .opacity)
                    ))
            }
            Button(action: home) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .background(Color.primary.opacity(adding ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { inside in withAnimation(.easeOut(duration: 0.12)) { adding = inside } }
            .tip("New tab  ⌘T", below: true)
        }
        .frame(height: 34)
    }
}

/// One tab: the board's name, which a double-click renames, or New Tab; and a close button on the current or the
/// hovered tab, except on a lone New Tab.
struct TabChip: View {
    let page: Tabs.Page
    let current: Bool
    let closes: Bool
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
            Spacer(minLength: 0)
            if closes, current || hovering {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close tab  ⌘W")
            }
        }
        .font(.system(size: 12.5, weight: current ? .semibold : .medium))
        .foregroundStyle(current ? Color.primary : Color.secondary)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(minWidth: 72, idealWidth: 170, maxWidth: 190, minHeight: 28, maxHeight: 28)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(current ? Color.white : Color.primary.opacity(hovering ? 0.07 : 0.035))
                .shadow(color: .black.opacity(current ? 0.1 : 0), radius: 3, y: 1)
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
