import SwiftUI

/// The snooze sheet: a grid of big tiles, three in a row, each with its icon in a coloured circle, its title and the
/// time it stands for. A click, Return on the selected tile, or its number key picks it. Pick Date turns the grid into a
/// calendar and a time, with Snooze to pick them.
struct SpotView: View {
    let spot: SpotInput

    private static let columns = 3
    private static let gap: CGFloat = 10
    private static let circle: CGFloat = 46
    private static let glyph = Font.system(size: 20, weight: .semibold)
    private static let hues: [Double] = [0.58, 0.08, 0.72, 0.12, 0.38, 0.95, 0.5, 0.82, 0.62]

    @State private var selected = 0
    @State private var isPickingDate = false
    @State private var date = Date().addingTimeInterval(86400)
    @FocusState private var isFocused: Bool

    private struct Tile {
        let id: String
        let title: String
        let icon: String
        let time: String
    }

    private var theme: SpotTheme { spot.theme }

    private var tiles: [Tile] {
        (1...9).compactMap { spot["tile.\($0)"] }.map { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            return Tile(id: parts[0], title: parts.count > 1 ? parts[1] : "", icon: parts.count > 2 ? parts[2] : "", time: parts.count > 3 ? parts[3] : "")
        }
    }

    var body: some View {
        Group {
            if isPickingDate { picker } else { grid }
        }
        .frame(width: spot.size.width, height: spot.size.height)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(phases: .down) { press in key(press) }
    }

    private var grid: some View {
        let rows = max(1, (tiles.count + Self.columns - 1) / Self.columns)
        let height = (spot.size.height - Self.gap * CGFloat(rows - 1)) / CGFloat(rows)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.gap), count: Self.columns), spacing: Self.gap) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                tileView(tile, index: index).frame(height: max(0, height))
            }
        }
    }

    private func tileView(_ tile: Tile, index: Int) -> some View {
        let color = Color(hue: Self.hues[index % Self.hues.count], saturation: 0.55, brightness: 0.92)
        return VStack(spacing: 8) {
            ZStack {
                Circle().fill(color)
                Image(systemName: tile.icon).font(Self.glyph).foregroundStyle(.white)
            }
            .frame(width: Self.circle, height: Self.circle)
            Text(tile.title).font(spot.font.title).foregroundStyle(theme.color.ink).lineLimit(1).minimumScaleFactor(0.75)
            Text(tile.time.isEmpty ? " " : tile.time).font(spot.font.detail).foregroundStyle(theme.color.ink.opacity(theme.color.secondary)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.color.ink.opacity(index == selected ? 0.1 : 0.04), in: .rect(cornerRadius: spot.corner))
        .contentShape(.rect)
        .onTapGesture { pick(index) }
        .onHover { if $0 { selected = index } }
    }

    private var picker: some View {
        VStack(spacing: Self.gap) {
            DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Button("Back") { isPickingDate = false }
                Spacer()
                Button("Snooze") { spot.send("date " + Self.iso(date)) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(Self.gap)
    }

    private func pick(_ index: Int) {
        guard tiles.indices.contains(index) else { return }
        selected = index
        if tiles[index].id == "date" {
            isPickingDate = true
        } else {
            spot.send(tiles[index].id)
        }
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard !isPickingDate else { return .ignored }
        switch press.key {
        case .leftArrow: selected = max(0, selected - 1)
        case .rightArrow: selected = min(tiles.count - 1, selected + 1)
        case .upArrow: selected = max(0, selected - Self.columns)
        case .downArrow: selected = min(tiles.count - 1, selected + Self.columns)
        case .return: pick(selected)
        default:
            guard let number = Int(press.characters), (1...tiles.count).contains(number) else { return .ignored }
            pick(number - 1)
        }
        return .handled
    }

    private static func iso(_ date: Date) -> String {
        let format = ISO8601DateFormatter()
        format.timeZone = .current
        return format.string(from: date)
    }
}
