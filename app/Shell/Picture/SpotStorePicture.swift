import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotStorePicture {
    private static let margin: CGFloat = 20
    private static let settle = 1.0

    static func run(path: String, window id: String? = nil, at destination: String? = nil, isLight: Bool = false) -> Never {
        SpotPicture.start(isLight: isLight)
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        Task { @MainActor in
            await model.reload()
            model.panelWillShow()
            guard let entry = model.cards.first(where: { model.place(ofSheet: $0.id) == .window && (id == nil || $0.id == id) }) else {
                FileHandle.standardError.write(Data(((id.map { "\($0) is not a spot whose sheet opens as a window." } ?? "No spot offers a window.") + "\n").utf8))
                exit(1)
            }
            if id == nil { model.openWindow(entry.id) } else { model.open(entry.id, at: destination) }
            for view in entry.spot.views.values { await SpotViews.shared.load(view) }
            await model.waitForShows()
            draw(model: model, id: entry.id, size: entry.spot.window?.size ?? SpotTokens.windowSize, to: path)
        }
        NSApplication.shared.run()
        exit(0)
    }

    private static func draw(model: SpotsModel, id: String, size: CGSize, to path: String) {
        let whole = CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin)
        let seed = URL(fileURLWithPath: path).lastPathComponent
        let edge = SpotRoundShape(.window)
        let store = ZStack {
            if !SpotPicture.isOnScreen {
                SpotWallpaper(seed: seed)
                SpotWallpaper.blurred(seed: seed, size: size)
                    .clipShape(edge)
                    .padding(margin)
            }
            SpotFloatView(model: model, id: id, fills: true) { _ in }
                .containerShape(edge)
                .padding(margin)
        }
        .frame(width: whole.width, height: whole.height)
        SpotPicture(of: store, size: whole, path: path).save(after: settle)
    }
}
