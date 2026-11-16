import OpenspotCore
import SwiftUI

struct SpotSlashMark: View {
    let model: SpotsModel

    var body: some View {
        if let slash = model.slash, model.openSheetID == nil, model.form == nil {
            Text("\(Text(slash.lead).foregroundStyle(.clear))\(Text("/\(slash.word)").foregroundStyle(SpotTheme.accent))\(hint)")
                .lineLimit(1)
        }
    }

    private var hint: Text {
        Text(model.slashPlaceholder.map { " \($0)" } ?? "").foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
    }
}
