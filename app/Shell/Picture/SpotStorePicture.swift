import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotStorePicture {
    private static let settle = 1.5
    private static let far = CGPoint(x: -9000, y: -9000)

    static func run(path: String, place: String?, spot: String?, review: String?, isTrying: Bool) -> Never {
        SpotPicture.start()
        let store = Store(places: .standard)
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        Task { @MainActor in
            await store.read()
            if let place {
                guard let chosen = store.placesInOrder.first(where: { name(of: $0) == place }) else {
                    fail("The Store has no place \(place). Name My spots or a source, such as Openspot.")
                }
                store.choose(chosen)
            }
            if let spot {
                await store.open(spot)
                guard store.page != nil else { fail("\(name(of: store.place)) has no spot \(spot).") }
            }
            if let review {
                await store.install(review)
                guard store.ask != nil else { fail("Openspot has no review of \(review) to show.") }
            }
            if isTrying {
                guard let page = store.page, let output = await SpotSample.output(of: page.spot, runsScript: page.runsSample, runs: model.runs) else {
                    fail("\(spot ?? "") has no sample data to try.")
                }
                let sample = StoreSample(id: page.id, output: output)
                draw(StoreTry(model: model, spot: page.spot, output: sample.output, hasSheet: sample.hasSheet) {}, to: path)
            } else {
                draw(StoreView(store: store, model: model), to: path)
            }
        }
        NSApplication.shared.run()
        exit(0)
    }

    private static func name(of place: StorePlace) -> String {
        place.source?.name ?? "My spots"
    }

    private static func fail(_ reason: String) -> Never {
        FileHandle.standardError.write(Data("\(reason)\n".utf8))
        exit(1)
    }

    private static func draw(_ view: some View, to path: String) {
        let content = view
            .environment(\.spotDrawsGlass, false)
            .environment(\.spotMoves, false)
        let window = SpotSheetWindow.make(pages: "Store", name: "store-picture", content: content)
        window.setFrameOrigin(far)
        window.orderBack(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
            MainActor.assumeIsolated {
                let shown = window.attachedSheet ?? window
                guard let frame = shown.contentView?.superview, let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { exit(1) }
                frame.cacheDisplay(in: frame.bounds, to: bitmap)
                exit(FileManager.default.createFile(atPath: path, contents: bitmap.representation(using: .png, properties: [:])) ? 0 : 1)
            }
        }
    }
}
