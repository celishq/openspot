import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SettingsPicture {
    private static let settle = 1.5
    private static let far = CGPoint(x: -9000, y: -9000)

    static func run(path: String, at place: String?, isLight: Bool) -> Never {
        SpotPicture.start(isLight: isLight)
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        var mac = SpotMac().mac
        mac.reads = SpotReads(frontApp: { nil })
        model.runs.api = CommandAPI(mac: mac, places: model.files, runs: model.runs)
        Task { @MainActor in
            await model.reload()
            model.panelWillShow()
            await model.waitForShows()
            await model.settingsBook.read()
            if let place { model.settingsBook.land(SettingsPage(place: place) ?? .general) }
            draw(model: model, isLight: isLight, to: path)
        }
        NSApplication.shared.run()
        exit(0)
    }

    private static func draw(model: SpotsModel, isLight: Bool, to path: String) {
        let content = SettingsView(model: model)
            .environment(\.spotDrawsGlass, false)
            .environment(\.spotMoves, false)
        let window = SpotSheetWindow.make(settings: model, content: content)
        window.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
        window.setFrameOrigin(far)
        window.orderBack(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
            MainActor.assumeIsolated {
                guard let frame = window.contentView?.superview, let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { exit(1) }
                frame.cacheDisplay(in: frame.bounds, to: bitmap)
                exit(FileManager.default.createFile(atPath: path, contents: bitmap.representation(using: .png, properties: [:])) ? 0 : 1)
            }
        }
    }
}
