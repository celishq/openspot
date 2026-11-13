import AppKit
import SwiftUI

/// The rim of a surface of a fixed size, drawn once into a picture for each size and theme. A card moves and shrinks this
/// picture on each frame of a push, which costs nothing, where a drawn or a layer rim is made again on each frame. It keeps
/// at most 8 MB of pictures, and starts again when it would hold more.
struct SpotRimPicture: View {
    let size: CGSize
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var scale

    private static let byteLimit = 8 << 20
    @MainActor private static var pictures: [Key: NSImage] = [:]
    @MainActor private static var bytes = 0

    var body: some View {
        let theme: SpotTheme = scheme == .dark ? .dark : .light
        Image(nsImage: Self.picture(of: .sides, size: size, radius: radius, theme: theme, scale: scale))
            .resizable()
            .frame(width: size.width, height: size.height)
            .overlay {
                Image(nsImage: Self.picture(of: .ends, size: size, radius: radius, theme: theme, scale: scale))
                    .resizable()
                    .blendMode(.plusLighter)
            }
        .allowsHitTesting(false)
    }

    @MainActor private static func picture(of part: Part, size: CGSize, radius: CGFloat, theme: SpotTheme, scale: CGFloat) -> NSImage {
        let key = Key(part: part, width: size.width, height: size.height, radius: radius, ends: theme.rimEnds, scale: scale)
        if let picture = pictures[key] { return picture }
        let renderer = ImageRenderer(content: Drawing(part: part, radius: radius, theme: theme).frame(width: size.width, height: size.height))
        renderer.scale = scale
        let picture = renderer.nsImage ?? NSImage(size: size)
        let cost = Int(size.width * scale) * Int(size.height * scale) * 4
        if bytes + cost > byteLimit {
            pictures = [:]
            bytes = 0
        }
        pictures[key] = picture
        bytes += cost
        return picture
    }

    private struct Key: Hashable {
        let part: Part
        let width: CGFloat
        let height: CGFloat
        let radius: CGFloat
        let ends: NSColor
        let scale: CGFloat
    }

    /// The two parts of the rim: the dark lines down the sides, and the light that is added at the top and foot.
    private enum Part {
        case sides
        case ends
    }

    /// One part of the rim as `SpotRim` draws it with layers.
    private struct Drawing: View {
        let part: Part
        let radius: CGFloat
        let theme: SpotTheme

        private static let stops: [CGFloat] = [0, 0.3, 0.7, 1]

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            let alpha = theme.rimEnds.alphaComponent
            switch part {
            case .sides:
                shape.strokeBorder(Self.gradient(Color(nsColor: SpotTheme.rimSides), SpotTheme.rimSideStrengths), lineWidth: 0.5)
            case .ends:
                Self.gradient(Color(nsColor: theme.rimEnds.withAlphaComponent(1)), [alpha, 0, 0, alpha])
                    .mask {
                        ZStack {
                            shape.strokeBorder(lineWidth: 2).opacity(0.3).blur(radius: 2).clipShape(shape)
                            shape.strokeBorder(lineWidth: 1).opacity(0.25)
                            shape.strokeBorder(lineWidth: 0.5).opacity(0.15)
                        }
                    }
            }
        }

        private static func gradient(_ colour: Color, _ strengths: [CGFloat]) -> LinearGradient {
            LinearGradient(
                stops: zip(strengths, stops).map { Gradient.Stop(color: colour.opacity($0.0), location: $0.1) },
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
