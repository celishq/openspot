import SwiftUI

/// The name and key of a control, which fades in after the pointer rests on it for a moment. Near an edge of the window
/// it lines up with that side of the control, so it stays whole.
struct Tip: ViewModifier {
    let text: String
    var below = false
    @State private var resting = false
    @State private var shown = false
    @State private var side = HorizontalAlignment.center

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { place in
                Color.clear.onChange(of: shown) { _, now in
                    guard now else { return }
                    let frame = place.frame(in: .global)
                    let width = NSApp.keyWindow?.frame.width ?? .greatestFiniteMagnitude
                    side = frame.midX + 90 > width ? .trailing : frame.midX < 90 ? .leading : .center
                }
            })
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
            .overlay(alignment: Alignment(horizontal: side, vertical: below ? .bottom : .top)) {
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

/// Undo and redo beside the sidebar button, in a round glass pill of the same height.
struct Corner: View {
    @ObservedObject var studio: Studio

    var body: some View {
        HStack(spacing: 0) {
            step("arrow.uturn.backward", "Undo  ⌘Z", enabled: studio.canUndo) { studio.undo() }
            Divider().frame(height: 14)
            step("arrow.uturn.forward", "Redo  ⇧⌘Z", enabled: studio.canRedo) { studio.redo() }
        }
        .padding(.horizontal, 3)
        .glassEffect(.regular.interactive(), in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private func step(_ symbol: String, _ help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 38, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .tip(help, below: true)
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
    /// Counts the changes to the boards on disk, such as one moved to the Trash, so the list reads them again.
    @Published var changes = 0
    /// The boards picked in the list.
    @Published var picking = Picking()
    /// Whether the list takes the keys, after a click in it.
    @Published var focused = false
    /// The folders of the list that show what they hold.
    @Published var expanded: Set<URL> = []
    /// Whether the search field shows, and its words.
    @Published var searching = false
    @Published var query = ""
}

/// The search field of the boards. It takes the keys when it shows on the start page, and when Command-F asks for it.
/// Escape clears it.
struct Search: View {
    @ObservedObject var drawer: Drawer
    var wide = false
    var takesFocus = true
    @FocusState private var typing: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search boards", text: $drawer.query)
                .textFieldStyle(.plain)
                .focused($typing)
                .onKeyPress(.escape) {
                    drawer.query = ""
                    typing = false
                    return .handled
                }
            if !drawer.query.isEmpty {
                Button { drawer.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: wide ? 15 : 13))
        .padding(.horizontal, wide ? 16 : 11)
        .frame(height: wide ? 42 : 32)
        .background(Capsule().fill(wide ? Color(white: 0.955) : Color.white))
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(typing ? 0.85 : 0), lineWidth: 2.5).padding(-1))
        .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
        .animation(.easeOut(duration: 0.15), value: typing)
        .onAppear { if takesFocus { typing = true } }
        .onChange(of: drawer.searching) { _, now in if now { typing = true } }
    }
}

/// The frames of the rows of the list, by board, so a drag knows which rows it passes.
struct RowFrames: PreferenceKey {
    static let defaultValue: [URL: CGRect] = [:]

    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The button that shows the list of boards, in a round glass pill beside the window buttons. While the list shows, it
/// sits in the list's top right corner.
struct Latch: View {
    @ObservedObject var drawer: Drawer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 30)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(drawer.open ? .identity : .regular.interactive(), in: Capsule())
        .shadow(color: .black.opacity(drawer.open ? 0 : 0.08), radius: 6, y: 2)
        .tip(drawer.open ? "Hide boards  ⌃⌘S" : "Show boards  ⌃⌘S", below: true)
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
