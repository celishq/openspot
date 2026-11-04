import Foundation
import OpenspotCore

@MainActor
@Observable
final class SpotsModel {
    struct Entry: Identifiable {
        let id: String
        let kind: SpotKind
        let size: SpotSize
        let symbol: String
        var state: SpotState
    }

    var entries: [Entry]
    var query = "" {
        didSet {
            if query != oldValue { selected = 0 }
        }
    }
    var selected = 0
    var openList: String?
    var itemSelected = 0
    var lastCommand = ""
    var isShown = false

    init(entries: [Entry] = SpotsModel.sample) {
        self.entries = entries
    }

    var visible: [Entry] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return entries }
        return entries.filter { $0.state.title.localizedCaseInsensitiveContains(text) }
    }

    func moveSelection(dx: Int, dy: Int) {
        let spots = placements
        guard let here = spots.first(where: { $0.index == selected }) else { return }
        let hereX = Double(here.column) + Double(here.size.columns) / 2
        let hereY = Double(here.row) + Double(here.size.rows) / 2
        let candidates: [(index: Int, score: Double)] = spots.compactMap { spot in
            guard spot.index != selected else { return nil }
            let x = Double(spot.column) + Double(spot.size.columns) / 2 - hereX
            let y = Double(spot.row) + Double(spot.size.rows) / 2 - hereY
            let along = x * Double(dx) + y * Double(dy)
            guard along > 0 else { return nil }
            let across = dx != 0 ? abs(y) : abs(x)
            return (spot.index, along + 2 * across)
        }
        if let best = candidates.min(by: { $0.score < $1.score }) {
            selected = best.index
        }
    }

    var selectedIsSlider: Bool {
        selectedEntry?.kind == .slider
    }

    func adjustSelected(by delta: Double) {
        guard let entry = selectedEntry, entry.kind == .slider, let index = index(of: entry) else { return }
        entries[index].state = entries[index].state.adjusted(by: delta)
        let level = entries[index].state.level ?? 0
        lastCommand = "Would run: \(entry.state.title) \(SpotAction.level(level).arguments.joined(separator: " "))"
    }

    func tap(_ id: String) {
        guard let position = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = position
        runSelected()
    }

    func setLevel(_ id: String, to value: Double) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].state = entries[index].state.withLevel(value)
        let level = entries[index].state.level ?? 0
        lastCommand = "Would run: \(entries[index].state.title) \(SpotAction.level(level).arguments.joined(separator: " "))"
    }

    func runSelected() {
        if openList != nil {
            runSelectedItem()
            return
        }
        guard let entry = selectedEntry, let index = index(of: entry) else { return }
        switch entry.kind {
        case .toggle:
            let action = SpotAction.toggle(entry.state)
            entries[index].state = SpotState(
                title: entry.state.title,
                subtitle: entry.state.subtitle,
                on: action.arguments == ["on"],
                items: entry.state.items
            )
            lastCommand = "Would run: \(entry.state.title) \(action.arguments.joined(separator: " "))"
        case .launch:
            lastCommand = "Would run: \(entry.state.title)"
        case .expand:
            openList = openList == entry.id ? nil : entry.id
            itemSelected = 0
        case .slider:
            break
        }
    }

    func openBigView() {
        guard let entry = selectedEntry else { return }
        lastCommand = "Would open big view: \(entry.state.title)"
    }

    private var selectedEntry: Entry? {
        let list = visible
        guard list.indices.contains(selected) else { return nil }
        return list[selected]
    }

    private func index(of entry: Entry) -> Int? {
        entries.firstIndex { $0.id == entry.id }
    }

    var placements: [SpotPlacement] {
        SpotGrid().place(visible.map(\.size))
    }

    var openEntry: Entry? {
        entries.first { $0.id == openList }
    }

    func closeList() {
        openList = nil
    }

    func moveItem(by step: Int) {
        guard let count = openEntry?.state.items?.count, count > 0 else { return }
        itemSelected = min(max(itemSelected + step, 0), count - 1)
    }

    func runSelectedItem() {
        guard let items = openEntry?.state.items, items.indices.contains(itemSelected) else { return }
        runItem(items[itemSelected])
    }

    func runItem(_ item: SpotItem) {
        lastCommand = "Would run: \(item.run)"
    }

    static let sample: [Entry] = [
        Entry(id: "airplane", kind: .toggle, size: .square, symbol: "airplane",
              state: SpotState(title: "Airplane Mode", subtitle: "Off", on: false)),
        Entry(id: "wifi", kind: .toggle, size: .wide, symbol: "wifi",
              state: SpotState(title: "Wi-Fi", subtitle: "VIRGIN-telco_5668", on: true)),
        Entry(id: "bluetooth", kind: .toggle, size: .small, symbol: "dot.radiowaves.left.and.right",
              state: SpotState(title: "Bluetooth", subtitle: "On", on: true)),
        Entry(id: "networks", kind: .expand, size: .wide, symbol: "network",
              state: SpotState(title: "Networks", subtitle: "3 known", items: [
                  SpotItem(title: "VIRGIN-telco_5668", run: "networks.sh VIRGIN-telco_5668"),
                  SpotItem(title: "VIRGIN-guest", run: "networks.sh VIRGIN-guest"),
                  SpotItem(title: "Office 5G", run: "networks.sh Office")
              ])),
        Entry(id: "focus", kind: .toggle, size: .small, symbol: "moon.fill",
              state: SpotState(title: "Focus", subtitle: "Off", on: false)),
        Entry(id: "stage", kind: .toggle, size: .small, symbol: "squares.leading.rectangle",
              state: SpotState(title: "Stage Manager", subtitle: "Off", on: false)),
        Entry(id: "mirror", kind: .toggle, size: .small, symbol: "rectangle.on.rectangle",
              state: SpotState(title: "Screen Mirroring", subtitle: "Off", on: false)),
        Entry(id: "caffeinate", kind: .launch, size: .strip, symbol: "cup.and.saucer.fill",
              state: SpotState(title: "Caffeinate", subtitle: "On · 2h left")),
        Entry(id: "display", kind: .slider, size: .strip, symbol: "sun.max.fill",
              state: SpotState(title: "Display", level: 70, min: 0, max: 100)),
        Entry(id: "sound", kind: .slider, size: .strip, symbol: "speaker.wave.2.fill",
              state: SpotState(title: "Sound", level: 30, min: 0, max: 100))
    ]
}
