import OpenspotCore
import SwiftUI

struct SpotSearchText: View {
    let model: SpotsModel
    let title: String

    var body: some View {
        TextField(title, text: Binding(get: { model.searchText }, set: { model.searchText = $0 }), prompt: Text(""))
    }
}
