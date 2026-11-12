import SwiftUI

/// The name and key of a control, which fades in after the pointer rests on it for a moment.
struct Tip: ViewModifier {
    let text: String
    var below = false
    @State private var resting = false
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                resting = inside
                if inside {
                    Task {
                        try? await Task.sleep(for: .seconds(0.8))
                        if resting { withAnimation(.easeOut(duration: 0.2)) { shown = true } }
                    }
                } else {
                    withAnimation(.easeIn(duration: 0.1)) { shown = false }
                }
            }
            .overlay(alignment: below ? .bottom : .top) {
                if shown {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                        .fixedSize()
                        .offset(y: below ? 38 : -40)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func tip(_ text: String, below: Bool = false) -> some View {
        modifier(Tip(text: text, below: below))
    }
}

/// One square button of the board's bars: a symbol, or the outline of a form. A loud knob, as in the toolbar, fills with
/// the accent when on, and a quiet one, as in the style panel, takes a light tint.
struct Knob: View {
    var symbol = ""
    var form: Figure.Form?
    let help: String
    var on = false
    var enabled = true
    var below = false
    var quiet = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let form {
                    Outline(form: form)
                        .stroke(style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                        .frame(width: 17, height: 17)
                } else {
                    Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                }
            }
            .frame(width: 34, height: 34)
            .foregroundStyle(on ? (quiet ? Color.accentColor : .white) : .primary)
            .background(on ? (quiet ? Color.accentColor.opacity(0.14) : Color.accentColor) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .tip(help, below: below)
    }
}

/// The outline of a form as the board draws it, with its marks, for an icon.
struct Outline: Shape {
    let form: Figure.Form

    func path(in rect: CGRect) -> Path {
        var path = Path(form.path(in: rect))
        if let marks = form.marks(in: rect) { path.addPath(Path(marks)) }
        return path
    }
}

/// A button that shows a short line drawn its way: solid, dashed, or with its heads.
struct Sample: View {
    var dashed = false
    var heads = Figure.Heads.none
    let help: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SwiftUI.Canvas { context, _ in
                var line = Path()
                line.move(to: CGPoint(x: 8, y: 17))
                line.addLine(to: CGPoint(x: 26, y: 17))
                for (tip, back) in heads == .none ? [] : heads == .end ? [(26.0, 21.0)] : [(26.0, 21.0), (8.0, 13.0)] {
                    line.move(to: CGPoint(x: back, y: 12))
                    line.addLine(to: CGPoint(x: tip, y: 17))
                    line.addLine(to: CGPoint(x: back, y: 22))
                }
                context.stroke(line, with: .color(on ? .accentColor : .primary), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round, dash: dashed ? [3, 4.5] : []))
            }
            .frame(width: 34, height: 34)
            .background(on ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tip(help)
    }
}

/// The tools at the bottom of the board, with the picker of shapes behind the ^ beside the shape tool, and images.
struct Toolbar: View {
    @ObservedObject var studio: Studio
    let picture: () -> Void
    @State private var picking = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tool.allCases) { tool in
                if tool == .shape {
                    Knob(symbol: "photo", help: "Image  ⇧⌘I", action: picture)
                }
                let title = tool == .shape ? studio.form.title : tool.title
                Knob(symbol: tool.symbol, form: tool == .shape ? studio.form : nil, help: "\(title)  \(String(tool.key).uppercased())", on: studio.tool == tool) {
                    studio.tool = tool
                    if tool != .select { studio.selection = [] }
                }
                if tool == .shape {
                    Knob(symbol: "chevron.up", help: "More shapes", on: picking) { picking.toggle() }
                        .popover(isPresented: $picking, arrowEdge: .top) {
                            Forms(studio: studio) { picking = false }
                        }
                }
            }
        }
        .padding(5)
        .modifier(Raised())
    }
}

/// The grid of forms that the shape tool draws.
struct Forms: View {
    @ObservedObject var studio: Studio
    let done: () -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 4), count: 4), spacing: 4) {
            ForEach(Figure.Form.allCases, id: \.self) { form in
                Knob(form: form, help: form.title, on: studio.form == form, below: true, quiet: true) {
                    studio.pick(form)
                    done()
                }
            }
        }
        .padding(10)
    }
}

/// Zoom and undo, at the bottom left of the board.
struct Corner: View {
    @ObservedObject var studio: Studio
    let zoom: (CGFloat) -> Void
    let fit: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Knob(symbol: "arrow.uturn.backward", help: "Undo  ⌘Z", enabled: studio.canUndo) { studio.undo() }
            Knob(symbol: "arrow.uturn.forward", help: "Redo  ⇧⌘Z", enabled: studio.canRedo) { studio.redo() }
            Divider().frame(height: 22).padding(.horizontal, 4)
            Knob(symbol: "minus", help: "Zoom out  ⌘−") { zoom(studio.zoom / 1.25) }
            Button(action: fit) {
                Text("\(Int((studio.zoom * 100).rounded()))%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .frame(width: 46, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tip("Show the whole board  ⇧1")
            Knob(symbol: "plus", help: "Zoom in  ⌘=") { zoom(studio.zoom * 1.25) }
        }
        .padding(5)
        .modifier(Raised())
    }
}

/// The colours, the fill, the dash, the weight and the ends of new and selected figures, then the alignment of words and
/// the lining up of selected figures, at the top right of the board. Each part shows only when it can act.
struct StylePanel: View {
    @ObservedObject var studio: Studio

    private var showsEnds: Bool {
        studio.tool == .arrow || studio.selection.contains { studio.board[$0]?.kind == .arrow }
    }

    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 2), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Figure.Ink.allCases, id: \.self) { ink in
                    Button {
                        studio.restyle { $0.ink = ink }
                    } label: {
                        Circle()
                            .fill(Color(nsColor: ink.color))
                            .frame(width: 18, height: 18)
                            .frame(width: 34, height: 34)
                            .background(studio.style.ink == ink ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tip(ink.rawValue.capitalized)
                }
            }
            Divider()
            LazyVGrid(columns: columns, spacing: 2) {
                Knob(symbol: "square", help: "No fill", on: !studio.style.filled, quiet: true) { studio.restyle { $0.filled = false } }
                Knob(symbol: "square.fill", help: "Fill", on: studio.style.filled, quiet: true) { studio.restyle { $0.filled = true } }
                Sample(help: "Solid", on: !studio.style.dashed) { studio.restyle { $0.dashed = false } }
                Sample(dashed: true, help: "Dashed", on: studio.style.dashed) { studio.restyle { $0.dashed = true } }
                ForEach(Figure.Weight.allCases, id: \.self) { weight in
                    Button {
                        studio.restyle { $0.weight = weight }
                    } label: {
                        Text(weight.rawValue.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(studio.style.weight == weight ? Color.accentColor : Color.primary)
                            .background(studio.style.weight == weight ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tip(["s": "Small", "m": "Medium", "l": "Large"][weight.rawValue] ?? "")
                }
            }
            if showsEnds {
                Divider()
                LazyVGrid(columns: columns, spacing: 2) {
                    Sample(heads: .none, help: "Line", on: studio.style.heads == .none) { studio.restyle { $0.heads = .none } }
                    Sample(heads: .end, help: "Arrow", on: studio.style.heads == .end) { studio.restyle { $0.heads = .end } }
                    Sample(heads: .both, help: "Arrow both ways", on: studio.style.heads == .both) { studio.restyle { $0.heads = .both } }
                }
            }
            if let words = studio.wording {
                Divider()
                LazyVGrid(columns: columns, spacing: 2) {
                    Knob(symbol: "text.alignleft", help: "Align text left", on: words.align == .left, quiet: true) { studio.align(.left) }
                    Knob(symbol: "text.aligncenter", help: "Centre text", on: words.align == .center, quiet: true) { studio.align(.center) }
                    Knob(symbol: "text.alignright", help: "Align text right", on: words.align == .right, quiet: true) { studio.align(.right) }
                    Color.clear.frame(width: 34, height: 34)
                    Knob(symbol: "arrow.up.to.line.compact", help: "Text at the top", on: words.place == .top, quiet: true) { studio.place(.top) }
                    Knob(symbol: "arrow.up.and.down", help: "Text in the middle", on: words.place == .middle, quiet: true) { studio.place(.middle) }
                    Knob(symbol: "arrow.down.to.line.compact", help: "Text at the bottom", on: words.place == .bottom, quiet: true) { studio.place(.bottom) }
                }
            }
            if studio.selection.count > 1 {
                Divider()
                LazyVGrid(columns: columns, spacing: 2) {
                    Knob(symbol: "align.horizontal.left", help: "Align left edges", quiet: true) { studio.arrange(.left) }
                    Knob(symbol: "align.horizontal.center", help: "Align centres", quiet: true) { studio.arrange(.center) }
                    Knob(symbol: "align.horizontal.right", help: "Align right edges", quiet: true) { studio.arrange(.right) }
                    Knob(symbol: "distribute.horizontal.center", help: "Spread across", quiet: true) { studio.arrange(.spreadAcross) }
                    Knob(symbol: "align.vertical.top", help: "Align top edges", quiet: true) { studio.arrange(.top) }
                    Knob(symbol: "align.vertical.center", help: "Align middles", quiet: true) { studio.arrange(.middle) }
                    Knob(symbol: "align.vertical.bottom", help: "Align bottom edges", quiet: true) { studio.arrange(.bottom) }
                    Knob(symbol: "distribute.vertical.center", help: "Spread down", quiet: true) { studio.arrange(.spreadDown) }
                }
            }
        }
        .padding(8)
        .modifier(Raised())
    }
}

/// The style panel, shown while a tool draws or a figure is selected.
struct StyleSlot: View {
    @ObservedObject var studio: Studio

    var body: some View {
        if studio.tool.draws || !studio.selection.isEmpty {
            StylePanel(studio: studio)
        }
    }
}

/// Whether the list of boards shows, and the board whose name it edits, shared by each board that the window shows in turn.
@MainActor
final class Drawer: ObservableObject {
    @Published var open = false
    @Published var naming: URL?
}

/// The button beside the window buttons that shows the list of boards, on a small rounded back.
struct Latch: View {
    @ObservedObject var drawer: Drawer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 34, height: 24)
                .background(Color.primary.opacity(drawer.open ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tip("Boards  ⌃⌘S", below: true)
    }
}

/// The list of boards that slides in from the left: each board, newest first, opens on a click and takes a new name on a
/// double-click, and the + makes a new board.
struct Sidebar: View {
    @ObservedObject var drawer: Drawer
    @ObservedObject var tabs: Tabs
    let shelf: Shelf
    let open: (URL) -> Void
    let make: () -> Void
    @State private var entries: [Shelf.Entry] = []
    @State private var name = ""
    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Boards").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Knob(symbol: "plus", help: "New board  ⌘N", below: true, action: make)
            }
            .padding(.leading, 8)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(entries) { entry in
                        row(entry)
                    }
                }
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
        .onReceive(tabs.$current) { _ in reload() }
        .onChange(of: drawer.naming) { _, file in
            if let file, let entry = entries.first(where: { $0.file == file }) { startNaming(entry) }
        }
    }

    private func reload() {
        entries = shelf.entries
    }

    private func row(_ entry: Shelf.Entry) -> some View {
        let current = entry.file.standardizedFileURL == tabs.current.file.standardizedFileURL
        return HStack(spacing: 10) {
            Group {
                if let picture = NSImage(contentsOf: entry.picture) {
                    Image(nsImage: picture).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white
                }
            }
            .frame(width: 48, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                if drawer.naming == entry.file {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .focused($typing)
                        .onSubmit { finish(entry) }
                        .onChange(of: typing) { _, now in if !now { finish(entry) } }
                } else {
                    Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                }
                Text(entry.edited.formatted(.relative(presentation: .named)).capitalized(with: nil))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(current ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { startNaming(entry) }
        .onTapGesture { if drawer.naming != entry.file { open(entry.file) } }
        .contextMenu {
            Button("Rename") { startNaming(entry) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.file]) }
        }
    }

    private func startNaming(_ entry: Shelf.Entry) {
        name = entry.title
        drawer.naming = entry.file
        typing = true
    }

    private func finish(_ entry: Shelf.Entry) {
        guard drawer.naming == entry.file else { return }
        drawer.naming = nil
        if let open = tabs.studio(for: entry.file) {
            open.rename(name)
        } else {
            try? shelf.rename(entry.file, to: name)
        }
        reload()
    }
}

/// The glass of a bar, with a soft shadow so it stands off the white board.
struct Raised: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
    }
}
