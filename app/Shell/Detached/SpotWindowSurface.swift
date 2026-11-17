import OpenspotCore
import SwiftUI

struct SpotWindowSurface: ViewModifier {
    @State private var given: CGFloat?

    @ViewBuilder
    private var corner: some View {
        if #available(macOS 27.0, *) {
            GeometryReader { room in
                Color.clear.onChange(of: room.concentricCornerRadii?.bottomTrailing, initial: true) { _, radius in
                    if let radius, radius != given { given = radius }
                }
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.spotSurfaceEdge, given.map { SurfaceEdge(radius: $0) } ?? .window)
            .background { Rectangle().fill(.regularMaterial).ignoresSafeArea() }
            .background { corner.ignoresSafeArea() }
    }
}
