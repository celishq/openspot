import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotPanelPicture {
    private static let settle = 0.8

    static func run(path: String, scene: PanelScene = PanelScene()) -> Never {
        SpotPicture.start(isLight: scene.isLight)
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        Task { @MainActor in
            await model.reload()
            model.panelWillShow()
            try? await Task.sleep(for: .milliseconds(300))
            await model.waitForShows()
            for sheet in model.sheets.values {
                guard let sampled = sheet.spot.sampled else { continue }
                sheet.update(sampled)
                sheet.show(need: .change)
            }
            try? await Task.sleep(for: .milliseconds(300))
            await model.waitForShows()
            if let search = scene.search {
                model.search(search)
                try? await Task.sleep(for: .milliseconds(300))
                await model.waitForShows()
            }
            model.selected = -1
            if scene.isHeld, let first = model.placements.first {
                model.hold([.command])
                model.point(at: .grid(CGPoint(x: first.rect.midX, y: first.rect.midY)))
            }
            let shapes = [(SpotFieldView.rect, SurfaceEdge(card: .strip).radius)] + model.placements.map {
                ($0.rect.offsetBy(dx: SpotTokens.halo, dy: SpotTokens.gridTop), SurfaceEdge(card: $0.size).radius)
            }
            let grid = scene.isHeld ? SpotTokens.gridTop + model.grid.height : SpotTokens.gridTop
            let bottom = max(shapes.map(\.0.maxY).max() ?? SpotTokens.gridTop, grid) + SpotTokens.hintBlock + SpotTokens.halo
            let size = CGSize(width: SpotTokens.panelWidth, height: min(bottom, SpotTokens.panelHeight))
            let seed = URL(fileURLWithPath: path).lastPathComponent
            let panel = ZStack(alignment: .topLeading) {
                if !SpotPicture.isOnScreen {
                    SpotWallpaper(seed: seed)
                    SpotWallpaper.blurred(seed: seed, size: size)
                        .overlay(Color.black.opacity(SpotWallpaper.glassShade))
                        .overlay(SpotTheme.glass)
                        .mask {
                            ZStack(alignment: .topLeading) {
                                ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                                    SpotRoundShape(radius: shape.1)
                                        .frame(width: shape.0.width, height: shape.0.height)
                                        .offset(x: shape.0.minX, y: shape.0.minY)
                                }
                            }
                            .frame(width: size.width, height: size.height, alignment: .topLeading)
                        }
                }
                SpotsView(model: model)
                    .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .environment(\.spotIsShown, true)
            SpotPicture(of: panel, size: size, path: path).save(after: settle)
        }
        NSApplication.shared.run()
        exit(0)
    }
}
