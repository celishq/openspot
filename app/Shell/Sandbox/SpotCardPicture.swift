import AppKit
import OpenspotCore
import SwiftUI

/// A picture of a card that its script draws, made by the real card view in a window that lies off every screen.
@MainActor
enum SpotCardPicture {
    private static let settle = 0.5
    private static let margin: CGFloat = 16

    /// Reads an output, draws its card at a size from the drawing for that size, writes the picture as a PNG and exits. An
    /// output with no drawing that fits the size exits with 1.
    static func run(text: String, size: SpotSize, path: String) -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let face = PluginOutput(text: text).face
        guard let drawing = face.drawing(for: size) else {
            FileHandle.standardError.write(Data("The card has no drawing for the size \(size.name). Print grid.\(size.name)= lines.\n".utf8))
            exit(1)
        }
        let card = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        let view = NSHostingView(rootView: SpotCardDrawing(drawing: drawing, face: face, card: size) { _, _ in }
            .padding(SpotTokens.cardPadding(for: size, isWidget: true))
            .frame(width: card.width, height: card.height)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .padding(margin)
            .background(SpotTheme.window)
            .preferredColorScheme(.dark))
        let frame = NSRect(x: -9000, y: -9000, width: card.width + 2 * margin, height: card.height + 2 * margin)
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
