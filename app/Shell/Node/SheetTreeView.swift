import OpenspotCore
import SwiftUI

struct SheetTreeView: View {
    let tree: ViewTree
    let pictureTimes: [String: Double]
    @Environment(\.spotNodeVariants) private var variants

    var body: some View {
        let style = tree.style.resolved(for: variants)
        NodeBox(children: tree.children, style: style, tree: tree)
            .modifier(NodeLook(style: style))
            .font(SpotType.body)
            .modifier(SpotInk())
            .environment(\.spotPictureTimes, pictureTimes)
    }
}
