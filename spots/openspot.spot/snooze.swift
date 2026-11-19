import SwiftUI

/// The snooze sheet: a grid of tiles, three in a row, centred in the sheet. Each tile holds its icon in the text colour
/// on a faint circle, its title and the time it stands for, in Openspot's title and detail fonts. A ring marks the
/// selected tile. A click, Return on the selected tile, or its number key picks it. Pick Date turns the grid into a
/// calendar and a time, with Snooze to pick them.
struct SpotView: View {
    let spot: SpotInput

    private static let columns = 3
    private static let gap: CGFloat = 10
    private static let tallness: CGFloat = 1.3
    private static let circle: CGFloat = 44
    private static let glyph = Font.system(size: 19, weight: .semibold)
    private static let rest = 0.04
    private static let lit = 0.1
    private static let ring = 0.8

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
        let side = (spot.size.width - Self.gap * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
        let rows = (tiles.count + Self.columns - 1) / Self.columns
        return VStack(spacing: Self.gap) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: Self.gap) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        let index = row * Self.columns + column
                        if index < tiles.count {
                            tileView(tiles[index], index: index).frame(width: side, height: side * Self.tallness)
                        } else {
                            Color.clear.frame(width: side, height: side * Self.tallness)
                        }
                    }
                }
            }
        }
    }

    private func tileView(_ tile: Tile, index: Int) -> some View {
        let isSelected = index == selected
        return VStack(spacing: 7) {
            ZStack {
                Circle().fill(theme.color.ink.opacity(0.12))
                Image(systemName: tile.icon).font(Self.glyph).foregroundStyle(theme.color.ink)
            }
            .frame(width: Self.circle, height: Self.circle)
            Text(tile.title).font(spot.font.title).foregroundStyle(theme.color.ink).lineLimit(1)
            Text(tile.time).font(spot.font.detail).foregroundStyle(theme.color.ink.opacity(theme.color.secondary)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.color.ink.opacity(isSelected ? Self.lit : Self.rest), in: .rect(cornerRadius: spot.corner))
        .overlay {
            if isSelected { RoundedRectangle(cornerRadius: spot.corner).strokeBorder(theme.color.ink.opacity(Self.ring), lineWidth: 1.5) }
        }
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
