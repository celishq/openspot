import AppKit
import OpenspotCore
import SwiftUI

/// A picture of a sheet, drawn by the real renderer in a window that lies off every screen.
@MainActor
enum SpotSheetPicture {
    private static let settle = 0.5
    private static let margin: CGFloat = 16

    private static func list(of output: PluginOutput) -> ItemList {
        var list = ItemList(items: output.items)
        list.take(drawing: output.drawing, templates: output.templates)
        return list
    }

    /// Reads a sheet, writes its picture as a PNG and exits. A sheet with no parts exits with 1. A Swift file of a view is
    /// built first, and the view draws in the area of its `view` component.
    static func run(text: String, path: String, view source: String? = nil) -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let output = PluginOutput(text: text)
        guard let panel = SheetParts(output: output) else {
            FileHandle.standardError.write(Data("The sheet has no parts.\n".utf8))
            exit(1)
        }
        let views = SpotViews()
        let source = source.map { URL(fileURLWithPath: $0).path }
        let values = Dictionary(grouping: output.view?.fields ?? [], by: \.key).mapValues { $0.map(\.value) }
        let size = SpotTokens.panelRect(panel).size
        let preview = SpotSheetPreview(panel: panel, list: Self.list(of: output), customView: { room in
            source.map { SpotCustomView(source: $0, values: values, card: .square, room: room, views: views) }
        })
        let view = NSHostingView(rootView: preview
            .padding(margin)
            .background(SpotTheme.window)
            .preferredColorScheme(.dark))
        let frame = NSRect(x: -9000, y: -9000, width: size.width + 2 * margin, height: size.height + 2 * margin)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        window.orderBack(nil)
        Task { @MainActor in
            if let source { await views.load(source) }
            DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
                MainActor.assumeIsolated {
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    let data = bitmap.representation(using: .png, properties: [:])
                    exit(FileManager.default.createFile(atPath: path, contents: data) ? 0 : 1)
                }
            }
        }
        NSApplication.shared.run()
        exit(0)
    }
}
