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

/// One square button of the board's bars: a symbol that shows when it is on.
struct Knob: View {
    let symbol: String
    let help: String
    var on = false
    var enabled = true
    var below = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
                .foregroundStyle(on ? Color.white : Color.primary)
                .background(on ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .tip(help, below: below)
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
                context.stroke(line, with: .color(on ? .white : .primary), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round, dash: dashed ? [3, 4.5] : []))
            }
            .frame(width: 34, height: 34)
            .background(on ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tip(help)
    }
}

/// The tools at the bottom of the board, with the picker of shapes behind the ^ beside the shape tool.
struct Toolbar: View {
    @ObservedObject var studio: Studio
    @State private var picking = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tool.allCases) { tool in
                if tool == .bundle { Divider().frame(height: 22).padding(.horizontal, 4) }
                let symbol = tool == .shape ? studio.form.symbol : tool.symbol
                let title = tool == .shape ? studio.form.title : tool.title
                Knob(symbol: symbol, help: "\(title)  \(String(tool.key).uppercased())", on: studio.tool == tool) {
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
                Knob(symbol: form.symbol, help: form.title, on: studio.form == form) {
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

/// The colours, the weight, the dash, the fill and the ends of new and selected figures, at the top right of the board.
struct StylePanel: View {
    @ObservedObject var studio: Studio

    private var showsEnds: Bool {
        studio.tool == .arrow || studio.selection.contains { studio.board[$0]?.kind == .arrow }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 4), spacing: 6) {
                ForEach(Figure.Ink.allCases, id: \.self) { ink in
                    Button {
                        studio.restyle { $0.ink = ink }
                    } label: {
                        Circle()
                            .fill(Color(nsColor: ink.color))
                            .frame(width: 18, height: 18)
                            .padding(4)
                            .overlay(Circle().strokeBorder(studio.style.ink == ink ? Color.accentColor : .clear, lineWidth: 2))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .tip(ink.rawValue.capitalized)
                }
            }
            Divider()
            HStack(spacing: 2) {
                Knob(symbol: "square", help: "No fill", on: !studio.style.filled) { studio.restyle { $0.filled = false } }
                Knob(symbol: "square.fill", help: "Fill", on: studio.style.filled) { studio.restyle { $0.filled = true } }
                Sample(help: "Solid", on: !studio.style.dashed) { studio.restyle { $0.dashed = false } }
                Sample(dashed: true, help: "Dashed", on: studio.style.dashed) { studio.restyle { $0.dashed = true } }
            }
            HStack(spacing: 2) {
                ForEach(Figure.Weight.allCases, id: \.self) { weight in
                    Button {
                        studio.restyle { $0.weight = weight }
                    } label: {
                        Text(weight.rawValue.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 34, height: 30)
                            .foregroundStyle(studio.style.weight == weight ? Color.white : Color.primary)
                            .background(studio.style.weight == weight ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tip(["s": "Small", "m": "Medium", "l": "Large"][weight.rawValue] ?? "")
                }
            }
            if showsEnds {
                Divider()
                HStack(spacing: 2) {
                    Sample(heads: .none, help: "Line", on: studio.style.heads == .none) { studio.restyle { $0.heads = .none } }
                    Sample(heads: .end, help: "Arrow", on: studio.style.heads == .end) { studio.restyle { $0.heads = .end } }
                    Sample(heads: .both, help: "Arrow both ways", on: studio.style.heads == .both) { studio.restyle { $0.heads = .both } }
                }
            }
        }
        .padding(10)
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

/// The top left of the board: the list of boards, and the title, which a click renames.
struct Header: View {
    @ObservedObject var studio: Studio
    let shelf: Shelf
    let open: (URL) -> Void
    let make: () -> Void
    let done: () -> Void
    @State private var listing = false
    @State private var title = ""
    @FocusState private var naming: Bool

    var body: some View {
        HStack(spacing: 4) {
            Knob(symbol: "sidebar.left", help: "Boards", on: listing, below: true) { listing.toggle() }
                .popover(isPresented: $listing, arrowEdge: .bottom) {
                    Boards(shelf: shelf, current: studio.file, open: { file in
                        listing = false
                        open(file)
                    }, make: {
                        listing = false
                        make()
                    })
                }
            TextField("Untitled board", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 60, maxWidth: 280)
                .fixedSize()
                .focused($naming)
                .onSubmit { naming = false }
                .onChange(of: naming) { _, now in
                    if !now {
                        studio.rename(title)
                        title = studio.board.title
                        done()
                    }
                }
                .tip("Rename", below: true)
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .modifier(Raised())
        .onAppear { title = studio.board.title }
        .onReceive(studio.$board.map(\.title).removeDuplicates()) { if !naming { title = $0 } }
    }
}

/// The boards beside this one, newest first, and a new board.
struct Boards: View {
    let shelf: Shelf
    let current: URL
    let open: (URL) -> Void
    let make: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: make) {
                Label("New board", systemImage: "plus.square.dashed")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider()
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(shelf.entries) { entry in
                        Button { open(entry.file) } label: {
                            HStack(spacing: 10) {
                                Group {
                                    if let picture = NSImage(contentsOf: entry.picture) {
                                        Image(nsImage: picture).resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.white
                                    }
                                }
                                .frame(width: 66, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                    Text("Edited \(entry.edited.formatted(.relative(presentation: .named)))")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(6)
                            .background(entry.file.standardizedFileURL == current.standardizedFileURL ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 380)
        }
        .padding(8)
        .frame(width: 300)
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
