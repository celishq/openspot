import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum SpotSheetWarmth {
    private static let life: TimeInterval = 0.5
    private static let rows = ["star", "folder", "doc", "gear", "clock"].map { SpotItem(title: $0.capitalized, subtitle: "Row", run: $0, picture: .symbol($0)) }

    static func draw() {
        let sheets = [SheetExamples.all[0], SheetExamples.tiles].map { SpotOutput(text: $0.text) }
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
