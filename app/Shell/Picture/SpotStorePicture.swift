import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotStorePicture {
    private static let margin: CGFloat = 20
    private static let settle = 1.0

    static func run(path: String, place: String?, spot: String?, review: String?) -> Never {
        SpotPicture.start()
        let store = Store(places: .standard)
        Task { @MainActor in
            await store.read()
            if let place {
                guard let chosen = store.placesInOrder.first(where: { name(of: $0, in: store) == place }) else {
                    fail("The Store has no place \(place). Name My spots or a source, such as Openspot.")
                }
                store.choose(chosen)
            }
            if let spot {
                await store.open(spot)
                guard store.page != nil else { fail("\(name(of: store.place, in: store)) has no spot \(spot).") }
            }
            if let review {
                await store.install(review)
                guard store.ask != nil else { fail("Openspot has no review of \(review) to show.") }
            }
            draw(store, to: path)
        }
        NSApplication.shared.run()
        exit(0)
    }

    private static func name(of place: StorePlace, in store: Store) -> String {
        guard case .source(let url) = place else { return "My spots" }
        return store.sources.first { $0.url == url }?.name ?? url.lastPathComponent
    }

    private static func fail(_ reason: String) -> Never {
        FileHandle.standardError.write(Data("\(reason)\n".utf8))
        exit(1)
    }

    private static func draw(_ store: Store, to path: String) {
        let size = SpotTokens.windowSize
        let whole = CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin)
        let seed = URL(fileURLWithPath: path).lastPathComponent
        let edge = SpotRoundShape(.window)
        let picture = ZStack {
            if !SpotPicture.isOnScreen {
                SpotWallpaper(seed: seed)
                SpotWallpaper.blurred(seed: seed, size: size)
                    .clipShape(edge)
                    .padding(margin)
            }
            StoreView(store: store, model: nil)
                .frame(width: size.width, height: size.height)
                .clipShape(edge)
                .padding(margin)
        }
        .frame(width: whole.width, height: whole.height)
        SpotPicture(of: picture, size: whole, path: path).save(after: settle)
    }
}
