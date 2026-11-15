import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotViewPlace = SpotViewPlace(model: nil)
}

@MainActor
struct SpotViewPlace: @MainActor Equatable {
    let model: SpotsModel?
    var place = ViewPlace.card

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model === rhs.model && lhs.place == rhs.place
    }

    func close() {
        model?.close(place)
    }

    func drew(_ source: String, in time: Duration) {
        model?.runs.usage.drew(view: source, seconds: Double(time.components.seconds) + Double(time.components.attoseconds) / 1e18)
    }
}
