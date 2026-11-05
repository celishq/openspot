import SwiftUI

/// The edge of a Control Center surface: light added to what lies behind at the top and bottom, with a narrow
/// glow inside it, and a thin dark line down the sides.
struct SpotRim: View {
    let radius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private func ends(_ strength: Double) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(strength), location: 0),
                .init(color: .white.opacity(0), location: 0.3),
                .init(color: .white.opacity(0), location: 0.7),
                .init(color: .white.opacity(strength), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var sides: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(0.5), location: 0.3),
                .init(color: .black.opacity(0.5), location: 0.7),
                .init(color: .black.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            shape.strokeBorder(sides, lineWidth: 0.5)
                .drawingGroup()
            ZStack {
                shape.strokeBorder(ends(1), lineWidth: 2)
                    .blur(radius: 2)
                    .opacity(0.3)
                    .clipShape(shape)
                shape.strokeBorder(ends(0.17), lineWidth: 1)
                shape.strokeBorder(ends(0.15), lineWidth: 0.5)
            }
            .drawingGroup()
            .blendMode(.plusLighter)
        }
    }
}
