import OpenspotCore
import SwiftUI

/// The drop target of the whole panel, which takes only `.spot` files and opens their review.
struct SpotAddDrop: DropDelegate {
    let model: SpotsModel

    func validateDrop(info: DropInfo) -> Bool {
        model.followDrag()
        return SpotFolder.isFile(SpotGridDrop.paths)
    }

    func performDrop(info: DropInfo) -> Bool {
        let paths = SpotGridDrop.paths
        guard SpotFolder.isFile(paths) else { return false }
        model.review(paths.map { URL(fileURLWithPath: $0) })
        return true
    }
}
