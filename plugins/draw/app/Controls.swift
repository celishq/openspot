import SwiftUI

/// One square button of the board's bars: a symbol that shows when it is on.
struct Knob: View {
    let symbol: String
    let help: String
    var on = false
    var enabled = true
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
        .help(help)
    }
}

/// A button that shows a short solid or dashed line.
struct Sample: View {
    let dashed: Bool
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Path { path in
                path.move(to: CGPoint(x: 8, y: 17))
                path.addLine(to: CGPoint(x: 26, y: 17))
            }
            .stroke(on ? Color.white : Color.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: dashed ? [3, 4.5] : []))
            .frame(width: 34, height: 34)
            .background(on ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(dashed ? "Dashed" : "Solid")
    }
}

/// The tools at the bottom of the board.
struct Toolbar: View {
    @ObservedObject var studio: Studio

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tool.allCases) { tool in
                if tool == .bundle { Divider().frame(height: 22).padding(.horizontal, 4) }
                Knob(symbol: tool.symbol, help: "\(tool.title) — \(String(tool.key).uppercased())", on: studio.tool == tool) {
                    studio.tool = tool
                    if tool != .select { studio.selection = [] }
                }
            }
        }
        .padding(5)
        .modifier(Raised())
    }
}

/// Zoom and undo, at the bottom left of the board.
struct Corner: View {
    @ObservedObject var studio: Studio
    let zoom: (CGFloat) -> Void
    let fit: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Knob(symbol: "arrow.uturn.backward", help: "Undo — ⌘Z", enabled: studio.canUndo) { studio.undo() }
            Knob(symbol: "arrow.uturn.forward", help: "Redo — ⇧⌘Z", enabled: studio.canRedo) { studio.redo() }
            Divider().frame(height: 22).padding(.horizontal, 4)
            Knob(symbol: "minus", help: "Zoom out — ⌘−") { zoom(studio.zoom / 1.25) }
            Button(action: fit) {
                Text("\(Int((studio.zoom * 100).rounded()))%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .frame(width: 46, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Show the whole board — ⇧1")
            Knob(symbol: "plus", help: "Zoom in — ⌘=") { zoom(studio.zoom * 1.25) }
        }
        .padding(5)
        .modifier(Raised())
    }
}

/// The colours, the weight, the dash and the fill of new and selected figures, at the top right of the board.
struct StylePanel: View {
    @ObservedObject var studio: Studio

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
                    .help(ink.rawValue.capitalized)
                }
            }
            Divider()
            HStack(spacing: 2) {
                Knob(symbol: "square", help: "No fill", on: !studio.style.filled) { studio.restyle { $0.filled = false } }
                Knob(symbol: "square.fill", help: "Fill", on: studio.style.filled) { studio.restyle { $0.filled = true } }
                Sample(dashed: false, on: !studio.style.dashed) { studio.restyle { $0.dashed = false } }
                Sample(dashed: true, on: studio.style.dashed) { studio.restyle { $0.dashed = true } }
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
                    .help(["s": "Small", "m": "Medium", "l": "Large"][weight.rawValue] ?? "")
                }
            }
        }
        .padding(10)
        .modifier(Raised())
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

/// The style panel, shown while a tool draws or a figure is selected.
struct StyleSlot: View {
    @ObservedObject var studio: Studio

    var body: some View {
        if studio.tool.draws || !studio.selection.isEmpty {
            StylePanel(studio: studio)
        }
    }
}
