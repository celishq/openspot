import AppKit
import AVFoundation
import OpenspotCore
import SwiftUI

struct SpotPeekVideo: NSViewRepresentable {
    final class Screen: NSView {
        let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private(set) var path: String?

        override init(frame: NSRect) {
            super.init(frame: frame)
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            self.layer = layer
            wantsLayer = true
            player.isMuted = true
        }

        required init?(coder: NSCoder) {
            nil
        }

        func show(_ path: String, isPlaying: Bool) {
            if path != self.path {
                self.path = path
                player.removeAllItems()
                looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: URL(fileURLWithPath: path)))
            }
            if isPlaying, player.rate == 0 { player.play() }
            if !isPlaying, player.rate != 0 { player.pause() }
        }
    }

    let path: String
    let isPlaying: Bool

    func makeNSView(context: Context) -> Screen {
        Screen()
    }

    func updateNSView(_ screen: Screen, context: Context) {
        screen.show(path, isPlaying: isPlaying)
    }

    static func dismantleNSView(_ screen: Screen, coordinator: ()) {
        screen.player.pause()
        screen.player.removeAllItems()
    }
}
