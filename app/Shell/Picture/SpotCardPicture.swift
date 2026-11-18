import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotCardPicture {
    private static let settle = 0.5
    private static let margin = SpotPictureStage<Color>.margin

    static func run(text: String, size: SpotSize, path: String) -> Never {
        SpotPicture.start()
        let output = SpotOutput(text: text)
        let face = output.face
        guard let layout = face.layout(for: size) else {
            FileHandle.standardError.write(Data("The card has no drawing for the size \(size.name). Print grid.\(size.name)= lines.\n".utf8))
            exit(1)
        }
        let card = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let shape = SpotRoundShape(radius: SurfaceEdge(card: size).radius)
        let stage = SpotPictureStage(size: card, radius: SurfaceEdge(card: size).radius, seed: URL(fileURLWithPath: path).lastPathComponent) {
            SpotCardDrawing(layout: layout, face: face, card: size) { _, _ in }
                .padding(SpotTokens.cardPadding(for: size, isWidget: true))
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
                .spotGlass(in: shape)
        }
        let picture = SpotPicture(of: stage, size: CGSize(width: card.width + 2 * margin, height: card.height + 2 * margin), path: path)
        Task { @MainActor in
            for picture in WebPictures.named(in: text) { _ = await WebPictures.shared.path(of: picture) }
            picture.save(after: settle)
        }
        NSApplication.shared.run()
        exit(0)
    }

    static func run(spot id: String, size: SpotSize, path: String) -> Never {
        SpotPicture.start()
        let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns())
        Task { @MainActor in
            await model.reload()
            guard let entry = model.entries.first(where: { $0.id == id }) else {
                FileHandle.standardError.write(Data("Openspot has no card for \(id). Run `openspot check spots` to see each file that does not load.\n".utf8))
                exit(1)
            }
            let draw = {
                let card = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
                let shown = model.entries.first { $0.id == id } ?? entry
                let stage = SpotPictureStage(size: card, radius: SurfaceEdge(card: size).radius, seed: URL(fileURLWithPath: path).lastPathComponent) {
                    SpotCardView(entry: shown, size: size, index: -1, isPressed: false, takesDrag: false, isDropTarget: false, model: model)
                        .environment(\.spotIsShown, true)
                }
                SpotPicture(of: stage, size: CGSize(width: card.width + 2 * margin, height: card.height + 2 * margin), path: path).save(after: settle)
            }
            if let sheet = model.sheets[id], entry.spot.readsState {
                sheet.afterAnswer(draw)
            } else {
                draw()
            }
        }
        NSApplication.shared.run()
        exit(0)
    }
}
