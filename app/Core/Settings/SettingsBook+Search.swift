import Foundation

extension SettingsBook {
    public static let searchSpot = Spot(
        id: "openspot/settings", name: "Settings", url: URL(fileURLWithPath: "/"), kind: .list, symbol: "gearshape",
        subtitle: "Access, spots, keys, look and account", isFound: false, isOnGrid: false
    )

    static let window = SpotItem(title: "Settings", subtitle: "Access, spots, keys, look and account", run: "", picture: .symbol("gearshape"), keywords: ["preferences", "access", "keys", "look", "account"])

    func readRows() {
        guard let api = model?.runs.api else { return }
        rowsRead?.cancel()
        rowsRead = Task { [weak self] in
            guard let rows = try? await api.settingRows(), !Task.isCancelled else { return }
            self?.take(rows: rows)
        }
    }

    func take(rows: [SettingRow]) {
        let items = [Self.window] + rows.map { row in
            SpotItem(title: row.title, subtitle: row.detail, run: row.item, picture: Icon(text: row.icon), place: row.name)
        }
        guard items != searchRows.all else { return }
        searchRows.replace(items)
        model?.searchRowsChanged()
    }

    static func place(of item: SpotItem) -> SettingsPlace? {
        item.run.isEmpty ? nil : .row(item.run)
    }
}
