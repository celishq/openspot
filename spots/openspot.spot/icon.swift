import SwiftUI

/// A grid of 16 by 16 dots that a click paints with the chosen colour, or clears when the dot has that colour, with the
/// palette, Reset and Save under it. Save sends the 256 dots to the spot as `save <dots>`.
struct SpotView: View {
    let spot: SpotInput
    @State private var dots: [Character] = Array(repeating: ".", count: 256)
    @State private var colour: Character = "0"

    private static let side = 16
    private static let palette: [(Character, Color)] = [
        ("0", Color(red: 0.11, green: 0.11, blue: 0.12)),
        ("1", Color(red: 0.96, green: 0.96, blue: 0.97)),
        ("2", Color(red: 1, green: 0.29, blue: 0.11)),
        ("3", Color(red: 1, green: 0.77, blue: 0)),
        ("4", Color(red: 0.2, green: 0.78, blue: 0.35)),
        ("5", Color(red: 0.04, green: 0.52, blue: 1))
    ]

    private var cell: CGFloat {
        let width: CGFloat = spot.size.width - 2 * spot.inset
        let height: CGFloat = spot.size.height - 2 * spot.inset - 76
        return max(8, min(width, height) / CGFloat(Self.side))
    }

    var body: some View {
        VStack(spacing: 12) {
            grid
            HStack(spacing: 8) {
                ForEach(Self.palette, id: \.0) { key, fill in
                    swatch(key, fill)
                }
            }
            HStack {
                Button("Reset") { spot.send("reset") }
                Spacer(minLength: 0)
                Button("Save") { spot.send("save \(String(dots))") }
                    .keyboardShortcut(.defaultAction)
            }
            .frame(width: cell * CGFloat(Self.side))
        }
        .frame(width: spot.size.width, height: spot.size.height, alignment: .top)
        .task(id: spot["dots"]) {
            if let saved = spot["dots"], saved.count == Self.side * Self.side { dots = Array(saved) }
        }
    }

    private func swatch(_ key: Character, _ fill: Color) -> some View {
        let ring: CGFloat = key == colour ? 2 : 0
        return Circle()
            .fill(fill)
            .overlay(Circle().stroke(spot.accent, lineWidth: ring))
            .overlay(Circle().stroke(spot.ink.opacity(0.2), lineWidth: 0.5))
            .frame(width: 20, height: 20)
            .onTapGesture { colour = key }
    }

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.side, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<Self.side, id: \.self) { column in
                        dot(row * Self.side + column)
                    }
                }
            }
        }
    }

    private func dot(_ index: Int) -> some View {
        let fill = Self.palette.first { $0.0 == dots[index] }?.1
        return Circle()
            .fill(fill ?? spot.ink.opacity(0.08))
            .padding(cell * 0.08)
            .frame(width: cell, height: cell)
            .contentShape(Rectangle())
            .onTapGesture { dots[index] = dots[index] == colour ? "." : colour }
    }
}
