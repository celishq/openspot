import OpenspotCore
import SwiftUI

struct SpotSlashMark: View {
    let model: SpotsModel

    var body: some View {
        if let slash = model.slash, model.openSheetID == nil, model.form == nil {
            Text("\(Text(slash.lead).foregroundStyle(.clear))\(Text("/\(slash.word)").foregroundStyle(SpotTheme.accent))")
                .lineLimit(1)
        }
    }
}
