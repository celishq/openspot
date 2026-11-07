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
        list.take(perLine: output.perLine ?? 1)
        return list
    }

    /// Reads a sheet, writes its picture as a PNG and exits. A sheet with no parts exits with 1.
    static func run(text: String, path: String) -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let output = PluginOutput(text: text)
        guard let panel = SpotPanel(output: output) else {
            FileHandle.standardError.write(Data("The sheet has no parts.\n".utf8))
            exit(1)
        }
        let size = SpotTokens.panelRect(panel).size
        let view = NSHostingView(rootView: SpotSheetPreview(panel: panel, list: Self.list(of: output))
            .padding(margin)
            .background(SpotTheme.window)
            .preferredColorScheme(.dark))
        let frame = NSRect(x: -9000, y: -9000, width: size.width + 2 * margin, height: size.height + 2 * margin)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        window.orderBack(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
            MainActor.assumeIsolated {
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let data = bitmap.representation(using: .png, properties: [:])
                exit(FileManager.default.createFile(atPath: path, contents: data) ? 0 : 1)
            }
        }
        NSApplication.shared.run()
        exit(0)
    }
}
