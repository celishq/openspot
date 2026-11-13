import SwiftUI

/// A grid of 12 by 12 rounded squares that a drag paints with the chosen colour, with the palette under it. A stroke that
/// starts on a square of that colour clears each square it passes instead. Each stroke's end sends the 144 squares to the
/// spot.
struct SpotView: View {
    let spot: SpotInput
    @State private var dots: [Character] = Array(repeating: ".", count: 144)
    @State private var sent = ""
    @State private var colour: Character = "0"
    @State private var stroke: Character?

    private static let side = 12
    private static let swatch: CGFloat = 20
    private static let palette: [(Character, Color)] = [
        ("0", Color(red: 0.11, green: 0.11, blue: 0.12)),
        ("1", Color(red: 0.96, green: 0.96, blue: 0.97)),
        ("2", Color(red: 1, green: 0.29, blue: 0.11)),
        ("3", Color(red: 1, green: 0.77, blue: 0)),
        ("4", Color(red: 0.2, green: 0.78, blue: 0.35)),
        ("5", Color(red: 0.04, green: 0.52, blue: 1))
    ]

    private var cell: CGFloat {
        let height = spot.size.height - Self.swatch - 12
        return max(8, min(spot.size.width, height) / CGFloat(Self.side))
    }

    var body: some View {
        VStack(spacing: 12) {
            grid
            HStack(spacing: 8) {
                ForEach(Self.palette, id: \.0) { key, fill in
                    swatch(key, fill)
                }
            }
        }
        .frame(width: spot.size.width, height: spot.size.height)
        .task(id: spot["dots"]) {
            if let saved = spot["dots"], saved.count == Self.side * Self.side, saved != sent { dots = Array(saved) }
        }
    }

    private func swatch(_ key: Character, _ fill: Color) -> some View {
        let ring: CGFloat = key == colour ? 2 : 0
        return Circle()
            .fill(fill)
            .overlay(Circle().stroke(spot.accent, lineWidth: ring))
            .overlay(Circle().stroke(spot.ink.opacity(0.2), lineWidth: 0.5))
            .frame(width: Self.swatch, height: Self.swatch)
            .onTapGesture { colour = key }
    }

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.side, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<Self.side, id: \.self) { column in
                        Square(fill: fill(of: dots[row * Self.side + column]), size: cell)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { paint(at: $0.location) }
                .onEnded { _ in end() }
        )
    }

    private func fill(of key: Character) -> Color {
        Self.palette.first { $0.0 == key }?.1 ?? spot.ink.opacity(0.08)
    }

    /// Paints or clears the square under the point, as the stroke's first square decided.
    private func paint(at point: CGPoint) {
        let column = Int(point.x / cell)
        let row = Int(point.y / cell)
        guard (0..<Self.side).contains(column), (0..<Self.side).contains(row) else { return }
        let index = row * Self.side + column
        let mark = stroke ?? (dots[index] == colour ? "." : colour)
        stroke = mark
        if dots[index] != mark { dots[index] = mark }
    }

    private func end() {
        stroke = nil
        sent = String(dots)
        spot.send(sent)
    }
}

/// One square of the grid, drawn again only when its colour changes.
private struct Square: View, Equatable {
    let fill: Color
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(fill)
            .padding(size * 0.08)
            .frame(width: size, height: size)
    }
}
