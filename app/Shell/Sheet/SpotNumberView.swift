import OpenspotCore
import SwiftUI

struct SpotNumberView: View {
    let part: SpotPart
    let font: Font
    let leastScale: CGFloat
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: SpotType.lineGap) {
            shown
                .font(font)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(leastScale)
            if let title = part.title {
                Text(title).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
            }
        }
        .modifier(SpotColorBar(color: part.color))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    private var shown: Text {
        part.numberPieces.reduce(Text(verbatim: "")) { text, piece in
            let run = Text(verbatim: piece.text)
            return Text("\(text)\(piece.isUnit ? run.foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight)) : run)")
        }
    }
}
