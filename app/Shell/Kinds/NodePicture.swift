import OpenspotCore
import SwiftUI

struct NodePicture: View {
    let icon: Icon?
    let size: CGSize
    @Environment(\.spotPictureTimes) private var times

    var body: some View {
        Group {
            if let path = icon?.image {
                SheetPicture(arrived: SpotPictureStore.Key(path: path, changed: times[path]))
            } else if let path = icon?.file {
                NodeFileThumbnail(path: path)
            } else if let icon {
                GeometryReader { room in
                    SpotItemIcon(icon: icon.file.map(FileIcon.init(path:)), glyph: icon.glyph, symbol: icon.symbol, size: SpotTokens.pictureSide(in: room.size))
                        .frame(width: room.size.width, height: room.size.height)
                }
            }
        }
        .frame(idealWidth: size.width, idealHeight: size.height)
    }
}
