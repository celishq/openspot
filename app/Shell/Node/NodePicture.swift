import OpenspotCore
import SwiftUI

struct NodePicture: View {
    let path: String?
    @Environment(\.spotPictureTimes) private var times

    var body: some View {
        if let path {
            SheetPicture(arrived: SpotPictureStore.Key(path: path, changed: times[path]))
                .frame(idealWidth: SpotTokens.cell, idealHeight: SpotTokens.cell)
        }
    }
}
