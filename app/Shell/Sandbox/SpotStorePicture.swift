import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotStorePicture {
    private static let margin: CGFloat = 20

    static func run(path: String) -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        model.reload()
        model.panelWillShow(holding: [])
        Task { @MainActor in
            guard let entry = model.cards.first(where: { model.place(ofSheet: $0.id) == .window }) else {
                FileHandle.standardError.write(Data("No spot offers a window.\n".utf8))
                exit(1)
            }
            model.openWindow(entry.id)
            if let view = entry.spot.view { await SpotViews.shared.load(view) }
            await model.waitForReads()
            draw(model: model, id: entry.id, to: path)
        }
        NSApplication.shared.run()
        exit(0)
    }

    private static func draw(model: SpotsModel, id: String, to path: String) {
        let size = SpotTokens.windowSize
        let whole = CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin)
        let seed = URL(fileURLWithPath: path).lastPathComponent
        let view = NSHostingView(rootView: ZStack {
            SpotWallpaper(seed: seed)
            SpotWallpaper.blurred(seed: seed, size: size)
                .clipShape(RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous))
                .padding(margin)
            SpotFloatView(model: model, id: id, fills: true) { _ in }
                .padding(margin)
        }
        .frame(width: whole.width, height: whole.height)
        .environment(\.spotDrawsBlur, false)
        .preferredColorScheme(.dark))
        let window = NSWindow(contentRect: NSRect(x: -9000, y: -9000, width: whole.width, height: whole.height), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        window.orderBack(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            MainActor.assumeIsolated {
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                exit(FileManager.default.createFile(atPath: path, contents: bitmap.representation(using: .png, properties: [:])) ? 0 : 1)
            }
        }
    }
}
