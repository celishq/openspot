import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotSheetPicture {
    private static let settle = 0.5
    private static let margin = SpotPictureStage<Color>.margin

    static func list(of output: SpotOutput) -> ItemList {
        var list = ItemList(items: output.items)
        list.take(drawing: output.drawing)
        return list
    }

    static func run(text: String, path: String, view source: String? = nil, spot: Spot? = nil) -> Never {
        SpotPicture.start()
        let output = SpotOutput(text: text)
        let panel = SheetParts(output: output)
        guard panel != nil || !output.items.isEmpty else {
            FileHandle.standardError.write(Data("The sheet has no blocks and no rows.\n".utf8))
            exit(1)
        }
        let views = SpotViews()
        let source = source.map { URL(fileURLWithPath: $0).path }
        let list = Self.list(of: output)
        let size = panel.map { SpotTokens.panelRect($0).size } ?? SpotTokens.floatSize(rows: list.shown.count)
        let preview = SpotSheetPreview(panel: panel, title: spot?.name ?? "Sheet", subtitle: spot?.subtitle ?? (spot == nil ? "Preview" : ""), symbol: spot?.symbol ?? "square.dashed", list: list, viewSource: source, views: views, seed: URL(fileURLWithPath: path).lastPathComponent)
        let picture = SpotPicture(of: preview.padding(margin), size: CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin), path: path)
        Task { @MainActor in
            if let source { await views.load(source) }
            for picture in WebPictures.named(in: text) { _ = await WebPictures.shared.path(of: picture) }
            picture.save(after: settle)
        }
        NSApplication.shared.run()
        exit(0)
    }
}
