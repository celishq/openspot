import SwiftUI

struct SpotFaded: ViewModifier {
    @Environment(\.spotFade) private var fade

    func body(content: Content) -> some View {
        content.opacity(fade)
    }
}
