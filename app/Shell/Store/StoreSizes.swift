import OpenspotCore
import SwiftUI

struct StoreSizes: View {
    let spot: Spot
    let face: ViewTree
    let sizes: [SpotSize]
    var width: CGFloat?

    private var rows: [[SpotSize]] {
        [[.small, .wide, .strip], [.square, .large]].map { $0.filter(sizes.contains) }.filter { !$0.isEmpty }
    }

    private var scale: CGFloat {
        guard let width else { return 1 }
        let widest = rows.map(Self.width(of:)).max() ?? 1
        return min(1, width / max(widest, 1))
    }

    private static func width(of row: [SpotSize]) -> CGFloat {
        let cards: CGFloat = row.map { SpotTokens.width(columns: $0.columns) }.reduce(0, +)
        return cards + CGFloat(row.count - 1) * SpotTokens.pageTileGap
    }

    var body: some View {
        let scale = scale
        VStack(alignment: .leading, spacing: SpotTokens.pageTileGap) {
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: SpotTokens.pageTileGap * scale) {
                    ForEach(row, id: \.self) { size in
                        StorePreviewUnit(label: "\(size.columns)×\(size.rows)") {
                            StoreCardPreview(spot: spot, face: face, size: size, scale: scale)
                        }
                    }
                }
            }
        }
    }
}
