import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotArrangePicture {
    private static let settle = 0.8
    private static let screen = CGSize(width: 1440, height: 900)
    private static let panelTop: CGFloat = 40

    static func run(path: String, scene: PanelScene) -> Never {
        SpotPicture.start()
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        Task { @MainActor in
            await model.reload()
            model.panelWillShow()
            try? await Task.sleep(for: .milliseconds(300))
            await model.waitForShows()
            model.selected = -1
            model.arrange()
            if let search = scene.search { model.searchShelf(search) }
            let origin = CGPoint(x: ((screen.width - SpotTokens.panelWidth) / 2).rounded(), y: panelTop)
            if let id = scene.swap { lift(id, in: model, panelOrigin: origin) }
            let seed = URL(fileURLWithPath: path).lastPathComponent
            let picture = ZStack(alignment: .topLeading) {
                SpotWallpaper(seed: seed)
                SpotWallpaper.blurred(seed: seed, size: screen)
                SpotArrangeView(model: model, size: screen, panelOrigin: origin, drawsCover: false)
                SpotsView(model: model)
                    .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
                    .offset(x: origin.x, y: origin.y)
                SpotCarriedCard(model: model, panelOrigin: origin)
            }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            .clipped()
            .environment(\.spotIsShown, true)
            SpotPicture(of: picture, size: screen, path: path).save(after: settle)
        }
        NSApplication.shared.run()
        exit(0)
    }

    private static func lift(_ id: String, in model: SpotsModel, panelOrigin: CGPoint) {
        guard let card = model.placements.last else { return }
        let grid = SpotTokens.gridOrigin()
        let start = CGPoint(x: -SpotTokens.panelWidth / 2, y: SpotTokens.gridTop)
        let target = CGPoint(x: grid.x + card.rect.minX + SpotTokens.cell / 3, y: grid.y + card.rect.minY + SpotTokens.cell / 3)
        model.dragShelfSpot(id, from: start, by: CGSize(width: target.x - start.x, height: target.y - start.y))
    }
}
