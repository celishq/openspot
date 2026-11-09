import OpenspotCore
import SwiftUI

/// The text field of the search. It reads the search itself, so that a change of the open sheet's rows or query reruns only
/// this field and not the panel around it.
struct SpotSearchText: View {
    let model: SpotsModel
    let title: String

    var body: some View {
        TextField(title, text: Binding(get: { model.searchText }, set: { model.searchText = $0 }), prompt: Text(""))
    }
}
