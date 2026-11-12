import OpenspotCore
import SwiftUI

/// The ground of a picture of the guide: a drawn wallpaper, and over it a surface of the panel's glass, a blur of the
/// wallpaper through its shape with the panel's rim, under the content.
struct SpotPictureStage<Content: View>: View {
    let size: CGSize
    let radius: CGFloat
    @ViewBuilder let content: Content

    static var margin: CGFloat { 48 }
    private static var shade: Double { 0.28 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            SpotWallpaper()
            SpotWallpaper()
                .blur(radius: SpotTheme.blur, opaque: true)
                .overlay(Color.black.opacity(Self.shade))
                .overlay(SpotTheme.glass)
                .mask { shape.frame(width: size.width, height: size.height) }
            content
                .frame(width: size.width, height: size.height)
                .overlay { SpotRimPicture(size: size, radius: radius) }
        }
        .frame(width: size.width + 2 * Self.margin, height: size.height + 2 * Self.margin)
    }
}

/// A dark blue-green wallpaper, which stands in for the desktop behind the panel and keeps clear of the accent colour.
struct SpotWallpaper: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.4], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Color(red: 0.04, green: 0.08, blue: 0.12), Color(red: 0.05, green: 0.16, blue: 0.20), Color(red: 0.08, green: 0.22, blue: 0.22),
                Color(red: 0.05, green: 0.12, blue: 0.18), Color(red: 0.07, green: 0.24, blue: 0.27), Color(red: 0.10, green: 0.30, blue: 0.26),
                Color(red: 0.03, green: 0.06, blue: 0.09), Color(red: 0.05, green: 0.13, blue: 0.16), Color(red: 0.07, green: 0.18, blue: 0.17),
            ]
        )
    }
}
