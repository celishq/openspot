import Foundation

public enum RowFilter {
    public static func matching(_ rows: [Row], query: String) -> [Row] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return rows }
        return rows.filter { row in
            row.title.localizedCaseInsensitiveContains(needle)
                || (row.subtitle?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }
}
