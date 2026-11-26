import Foundation

extension SpotRuns {
    var iconTypes: [Manifest.RowType] {
        sheets.values.map(\.spot).filter { !$0.types.isEmpty }.sorted { $0.id < $1.id }.flatMap { $0.types.filter { $0.icon != nil } }
    }
}
