import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotViewPlace = SpotViewPlace(model: nil)
}

@MainActor
struct SpotViewPlace: @MainActor Equatable {
    let model: SpotsModel?
    var detached: String?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model === rhs.model && lhs.detached == rhs.detached
    }

    func close() {
        guard let model else { return }
        if let detached {
            model.land(detached)
        } else {
            model.closeSheet(moving: true)
        }
    }

    func drew(_ source: String, in time: Duration) {
        model?.runs.usage.drew(view: source, seconds: Double(time.components.seconds) + Double(time.components.attoseconds) / 1e18)
    }
}
