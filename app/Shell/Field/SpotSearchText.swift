import OpenspotCore
import SwiftUI

struct SpotSearchText: View {
    let model: SpotsModel
    let sheetWord: String?

    var body: some View {
        TextField("\(SearchPrompt.verb) \(sheetWord ?? model.promptWord)", text: Binding(get: { model.searchText }, set: { model.search($0) }), prompt: Text(""))
            .foregroundStyle(model.marksSlash ? SpotColor.clear : SpotTheme.ink)
    }
}
