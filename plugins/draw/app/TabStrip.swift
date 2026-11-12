import SwiftUI

/// The tabs of the open boards beside the window buttons, and a + for a new board. A tab grows in when it opens and folds
/// away when it closes.
struct TabStrip: View {
    @ObservedObject var tabs: Tabs
    let show: (Studio) -> Void
    let close: (Studio) -> Void
    let make: () -> Void
    @State private var adding = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.studios, id: \.file) { studio in
                TabChip(studio: studio, current: studio === tabs.current, show: { show(studio) }, close: { close(studio) })
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4, anchor: .leading).combined(with: .opacity),
                        removal: .scale(scale: 0.2, anchor: .leading).combined(with: .opacity)
                    ))
            }
            Button(action: make) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 28)
                    .background(Color.primary.opacity(adding ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { inside in withAnimation(.easeOut(duration: 0.12)) { adding = inside } }
            .tip("New board  ⌘N", below: true)
        }
        .frame(height: 34)
    }
}

/// One tab: the board's name, which a double-click renames, and a close button on the current or the hovered tab.
struct TabChip: View {
    @ObservedObject var studio: Studio
    let current: Bool
    let show: () -> Void
    let close: () -> Void
    @State private var hovering = false
    @State private var naming = false
    @State private var name = ""
    @FocusState private var typing: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
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
            Spacer(minLength: 0)
            if current || hovering {
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
        .onTapGesture(count: 2) {
            name = studio.board.title
            naming = true
            typing = true
        }
        .onTapGesture(perform: show)
    }
}
