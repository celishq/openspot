import OpenspotCore
import SwiftUI

struct SpotWindowSurface: ViewModifier {
    @State private var window = SurfaceEdge.window

    @ViewBuilder
    private var corner: some View {
        if #available(macOS 27.0, *) {
            GeometryReader { room in
                Color.clear.onChange(of: room.concentricCornerRadii?.bottomTrailing, initial: true) { _, radius in
                    if let radius, radius != window.radius { window = SurfaceEdge(radius: radius) }
                }
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.spotSurfaceEdge, window)
            .background { Rectangle().fill(.regularMaterial).ignoresSafeArea() }
            .background { corner.ignoresSafeArea() }
    }
}
