import OpenspotCore
import SwiftUI

struct SpotWorkingSymbol: View {
    let entry: SpotsModel.Entry
    @Environment(\.spotViewPlace) private var place

    var body: some View {
        if entry.item == nil, place.model?.workingIDs.contains(entry.id) == true {
            SpotBreathingSymbol(name: "sparkles")
        } else {
            Image(systemName: entry.symbol)
        }
    }
}
