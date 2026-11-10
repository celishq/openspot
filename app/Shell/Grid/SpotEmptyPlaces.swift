import OpenspotCore
import SwiftUI

/// The places of the grid that no card takes, in Edit Spots: a faint ring in each, drawn as one path, so that the person
/// sees where the panel has room.
struct SpotEmptyPlaces: View {
    let placements: [SpotPlacement]
    let columns: Int
    let rows: Int

    var body: some View {
        let taken = Set(placements.flatMap { place in
            (place.row..<(place.row + place.size.rows)).flatMap { row in
                (place.column..<(place.column + place.size.columns)).map { row * columns + $0 }
            }
        })
        Path { path in
            for row in 0..<rows {
                for column in 0..<columns where !taken.contains(row * columns + column) {
                    path.addEllipse(in: SpotPlacement(index: 0, row: row, column: column, size: .small).rect.insetBy(dx: 0.5, dy: 0.5))
                }
            }
        }
        .stroke(SpotTheme.ink.opacity(SpotTheme.track), lineWidth: 1)
        .allowsHitTesting(false)
    }
}
