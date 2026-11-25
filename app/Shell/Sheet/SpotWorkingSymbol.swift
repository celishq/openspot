import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotWorking: Set<String> = []
}

struct SpotWorkingSymbol: View {
    let entry: SpotsModel.Entry
    @Environment(\.spotWorking) private var working

    var body: some View {
        if entry.item == nil, working.contains(entry.id) {
            SpotBreathingSymbol(name: "sparkles")
        } else {
            Image(systemName: entry.symbol)
        }
    }
}
