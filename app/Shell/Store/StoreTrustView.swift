import OpenspotCore
import SwiftUI

struct StoreTrustView: View {
    let lines: [ReviewLine]
    @State private var isShowingFiles = false

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: SpotTokens.wordsGap, verticalSpacing: SpotTokens.storeTileLineGap) {
            ForEach(lines.filter { !$0.isFiles }, id: \.title) { line in
                GridRow {
                    Text(line.title)
                        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                        .frame(width: SpotTokens.storeTrustTitleWidth, alignment: .leading)
                    Text(line.words.joined(separator: "\n"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            if let files = lines.first(where: \.isFiles) {
                GridRow {
                    Button(isShowingFiles ? "Hide Files" : "Show Files") { isShowingFiles.toggle() }
                        .buttonStyle(.link)
                        .gridCellColumns(2)
                }
                if isShowingFiles {
                    GridRow {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        Text(files.words.joined(separator: "\n"))
                            .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
