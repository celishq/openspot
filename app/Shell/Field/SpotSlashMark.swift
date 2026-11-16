import OpenspotCore
import SwiftUI

struct SpotSlashMark: View {
    let model: SpotsModel

    var body: some View {
        if let slash = model.slash, model.marksSlash {
            Text("\(Text(slash.lead))\(Text("/\(slash.word)").foregroundStyle(SpotTheme.accent))\(Text(slash.tail))\(hint)")
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
        }
    }

    private var hint: Text {
        Text(model.slashPlaceholder.map { " \($0)" } ?? "").foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
    }
}
