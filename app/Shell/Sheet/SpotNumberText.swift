import OpenspotCore
import SwiftUI

/// The shown value of a number as one text, with its unit drawn faint.
struct SpotNumberText: View {
    let part: SpotPart

    var body: Text {
        part.numberPieces.reduce(Text(verbatim: "")) { text, piece in
            let run = Text(verbatim: piece.text)
            return Text("\(text)\(piece.isUnit ? run.foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight)) : run)")
        }
    }
}
