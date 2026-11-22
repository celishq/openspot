import OpenspotCore
import SwiftUI

struct SheetTreeView: View {
    let tree: ViewTree
    let pictureTimes: [String: Double]
    @Environment(\.spotNodeVariants) private var place
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let variants = place.union([scheme == .dark ? .dark : .light])
        let style = tree.style.resolved(for: variants)
        NodeBox(children: tree.children, style: style, tree: tree)
            .environment(\.spotNodeVariants, variants)
            .modifier(NodeLook(style: style))
            .font(SpotType.body)
            .modifier(SpotInk())
            .environment(\.spotPictureTimes, pictureTimes)
    }
}
