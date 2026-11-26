import OpenspotCore
import SwiftUI

struct StoreTrustView: View {
    let lines: [ReviewLine]

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: SpotTokens.wordsGap, verticalSpacing: SpotTokens.storeTileLineGap) {
            ForEach(lines, id: \.title) { line in
                GridRow {
                    Text(line.title)
                        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                        .frame(width: SpotTokens.storeTrustTitleWidth, alignment: .leading)
                    Text(line.words.joined(separator: line.title == "Files" ? ", " : "\n"))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .font(SpotType.body)
    }
}
