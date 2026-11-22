import OpenspotCore
import SwiftUI

struct NodePicture: View {
    let icon: Icon?
    @Environment(\.spotPictureTimes) private var times

    var body: some View {
        Group {
            if let path = icon?.image {
                SheetPicture(arrived: SpotPictureStore.Key(path: path, changed: times[path]))
            } else if let icon {
                GeometryReader { room in
                    SpotItemIcon(icon: icon.file.map(FileIcon.init(path:)), glyph: icon.glyph, symbol: icon.symbol, size: SpotTokens.pictureSide(in: room.size))
                        .frame(width: room.size.width, height: room.size.height)
                }
            }
        }
        .frame(idealWidth: SpotTokens.cell, idealHeight: SpotTokens.cell)
    }
}
