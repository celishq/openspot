import AppKit
import OpenspotCore
import SwiftUI

struct StoreSpotMenu: View {
    let store: Store
    let model: SpotsModel?
    let id: String
    let spot: Spot
    let isCore: Bool
    let opens: Bool

    var body: some View {
        if let model {
            if opens {
                Button("Open") { model.openSpot(id) }
            }
            if model.hasSettings(ofSpot: id) {
                Button("Settings") { model.openSettings(ofSpot: id) }
            }
        }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([spot.url.deletingLastPathComponent()]) }
        if !isCore, let model {
            Divider()
            Button("Remove", role: .destructive) { model.removeSpot(id) }
        }
    }
}
