import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotSheetPicture {
    private static let settle = 0.5
    private static let margin = SpotPictureStage<Color>.margin

    static func list(of output: Frame) -> ItemList {
        var list = ItemList(items: output.items)
        list.take(perLine: output.drawing.columns)
        return list
    }

    static func run(text: String, path: String, view source: String? = nil, spot: Spot? = nil, isLight: Bool = false) -> Never {
        SpotPicture.start(isLight: isLight)
        let file = source.map { URL(fileURLWithPath: $0) }
        let kinds = spot?.kinds ?? file.map { BlockKind.kinds(views: [$0.deletingPathExtension().lastPathComponent: $0.path]) } ?? BlockKind.all
        let output = Frame(text: text, kinds: kinds)
        let panel = SheetParts(output: output, variants: [.sheet, isLight ? .light : .dark])
        guard panel != nil || !output.items.isEmpty else {
            FileHandle.standardError.write(Data("The sheet has no blocks and no rows.\n".utf8))
            exit(1)
        }
        let list = Self.list(of: output)
        let size = SpotSheetBody.size(of: panel, list: list)
        let preview = SpotSheetPreview(panel: panel, title: spot?.name ?? "Sheet", subtitle: spot?.subtitle ?? (spot == nil ? "Preview" : ""), symbol: spot?.symbol ?? "square.dashed", list: list, seed: URL(fileURLWithPath: path).lastPathComponent)
        let picture = SpotPicture(of: preview.padding(margin), size: CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin), path: path)
        Task { @MainActor in
            for node in output.tree.nodes.values.compactMap(\.source) { await SpotViews.shared.load(node) }
            for picture in WebPictures.named(in: text) { _ = await WebPictures.shared.path(of: picture) }
            picture.save(after: settle)
        }
        NSApplication.shared.run()
        exit(0)
    }
}
