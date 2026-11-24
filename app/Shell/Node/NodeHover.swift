import SwiftUI

struct NodeHover: ViewModifier {
    let isFollowed: Bool
    @Binding var isHovered: Bool

    func body(content: Content) -> some View {
        if isFollowed {
            content.onHover { inside in
                if inside != isHovered { isHovered = inside }
            }
        } else {
            content
        }
    }
}
