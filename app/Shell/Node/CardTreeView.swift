import OpenspotCore
import SwiftUI

struct CardTreeView: View {
    let tree: ViewTree
    let size: SpotSize
    var isPressed = false
    var model: SpotsModel?
    var index = -1

    var body: some View {
        let follows = !tree.places.isDisjoint(with: [.selected, .focus])
        let isSelected = follows && model?.selected == index
        SheetTreeView(tree: tree, pictureTimes: [:])
            .environment(\.spotNodeVariants, Style.Variant.card(size).union(isPressed ? [.pressed] : []).union(isSelected ? [.selected, .focus] : []))
    }
}
