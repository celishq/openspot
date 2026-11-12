import AppKit
import OpenspotCore
import SwiftUI

/// A picture of the panel with each installed spot on its grid, after the reads of the open panel: the real panel view over
/// a wallpaper, with glass drawn at the field and at each card, since the panel's own blur does not show in a picture.
@MainActor
enum SpotPanelPicture {
    private static let settle = 0.8

    /// Opens the panel of the installed spots, draws it, writes the picture as a PNG and exits.
    static func run(path: String) -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        model.reload()
        model.panelWillShow(holding: [])
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            await model.waitForReads()
            model.selected = -1
            let shapes = [(SpotFieldView.rect, SpotTokens.corner(for: .strip))] + model.placements.map {
                ($0.rect.offsetBy(dx: SpotTokens.halo, dy: SpotTokens.gridTop), SpotTokens.corner(for: $0.size))
            }
            let bottom = (shapes.map(\.0.maxY).max() ?? SpotTokens.gridTop) + SpotTokens.hintBlock + SpotTokens.halo
            let size = CGSize(width: SpotTokens.panelWidth, height: min(bottom, SpotTokens.panelHeight))
            let seed = URL(fileURLWithPath: path).lastPathComponent
            let view = NSHostingView(rootView: ZStack(alignment: .topLeading) {
                SpotWallpaper(seed: seed)
                SpotWallpaper.blurred(seed: seed, size: size)
                    .overlay(Color.black.opacity(SpotWallpaper.shade))
                    .overlay(SpotTheme.glass)
                    .mask {
                        ZStack(alignment: .topLeading) {
                            ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                                RoundedRectangle(cornerRadius: shape.1, style: .continuous)
                                    .frame(width: shape.0.width, height: shape.0.height)
                                    .offset(x: shape.0.minX, y: shape.0.minY)
                            }
                        }
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                    }
                SpotsView(model: model)
                    .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
                ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                    SpotRimPicture(size: shape.0.size, radius: shape.1)
                        .offset(x: shape.0.minX, y: shape.0.minY)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .environment(\.spotIsShown, true)
            .environment(\.spotDrawsBlur, false)
            .preferredColorScheme(.dark))
            let window = NSWindow(contentRect: NSRect(x: -9000, y: -9000, width: size.width, height: size.height), styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = view
            window.orderBack(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
                MainActor.assumeIsolated {
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    let data = bitmap.representation(using: .png, properties: [:])
                    exit(FileManager.default.createFile(atPath: path, contents: data) ? 0 : 1)
                }
            }
        }
        NSApplication.shared.run()
        exit(0)
    }
}
