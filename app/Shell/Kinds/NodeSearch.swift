import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotSearchTitle = ""
}

struct NodeSearch: View {
    @Environment(\.spotViewPlace) private var place
    @Environment(\.spotSearchTitle) private var title

    var body: some View {
        SpotSheetSearchRow(title: title, query: query)
    }

    private var query: String {
        guard case .sheet = place.place else { return "" }
        return place.model?.searchText ?? ""
    }
}
