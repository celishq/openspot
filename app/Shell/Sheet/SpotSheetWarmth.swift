import AppKit
import OpenspotCore
import SwiftUI

/// Sheets that the app draws once as it starts, in a window off every screen: one of menus and text areas, one of emoji
/// tiles, and a list. The first sheet that a person opens then finds the code of these views and the emoji font ready. The
/// focus of the panel stays where it was.
@MainActor
enum SpotSheetWarmth {
    private static let life: TimeInterval = 0.5
    private static let rows = ["star", "folder", "doc", "gear", "clock"].map { SpotItem(title: $0.capitalized, subtitle: "Row", run: $0, symbol: $0) }

    /// Draws each sheet once, and lets go of the window after a short life.
    static func draw() {
        let sheets = [SheetExamples.all[0], SheetExamples.tiles].map { PluginOutput(text: $0.text) }
        let view = VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sheets.enumerated()), id: \.offset) { _, output in
                if let panel = SheetParts(output: output) {
                    SpotSheetPreview(panel: panel, list: SpotSheetPicture.list(of: output))
                }
            }
            SpotRowsView(list: ItemList(items: rows), onRun: { _ in })
                .frame(width: SpotTokens.panelWidth, height: 5 * SpotTokens.listRowHeight)
        }
        let host = NSHostingView(rootView: view.preferredColorScheme(.dark))
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(x: -9000, y: -9000, width: size.width, height: size.height), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderBack(nil)
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + life) {
            window.orderOut(nil)
            window.contentView = nil
        }
    }
}
