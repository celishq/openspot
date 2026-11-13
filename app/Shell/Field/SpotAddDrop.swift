import OpenspotCore
import SwiftUI

/// The drop target of the whole panel, which takes only `.spot` files and opens their review.
struct SpotAddDrop: DropDelegate {
    let model: SpotsModel

    func validateDrop(info: DropInfo) -> Bool {
        model.followDrag()
        return SpotPackage.isFile(SpotGridDrop.paths)
    }

    func performDrop(info: DropInfo) -> Bool {
        let paths = SpotGridDrop.paths
        guard SpotPackage.isFile(paths) else { return false }
        model.review(paths.map { URL(fileURLWithPath: $0) })
        return true
    }
}
