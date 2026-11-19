import AppKit
import OpenspotCore
import SwiftUI

struct SpotMovingPicture: NSViewRepresentable {
    let frames: PictureFrames
    let gravity: CALayerContentsGravity
    let isPlaying: Bool

    final class Stage: NSView {
        private let picture = CALayer()
        private var frames: PictureFrames?

        init() {
            super.init(frame: .zero)
            layer = picture
            wantsLayer = true
            picture.masksToBounds = true
        }

        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func take(_ moving: SpotMovingPicture) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            picture.contentsGravity = moving.gravity
            if frames !== moving.frames {
                frames = moving.frames
                build(moving.frames)
            }
            CATransaction.commit()
            play(moving.isPlaying)
        }

        private func build(_ frames: PictureFrames) {
            picture.contents = frames.images.first
            picture.speed = 1
            picture.timeOffset = 0
            picture.beginTime = 0
            let flip = CAKeyframeAnimation(keyPath: "contents")
            flip.values = frames.images
            flip.keyTimes = frames.keyTimes.map { NSNumber(value: $0) }
            flip.calculationMode = .discrete
            flip.duration = frames.duration
            flip.repeatCount = .infinity
            flip.isRemovedOnCompletion = false
            picture.add(flip, forKey: "frames")
        }

        private func play(_ isPlaying: Bool) {
            guard isPlaying != (picture.speed != 0) else { return }
            if isPlaying {
                let paused = picture.timeOffset
                picture.speed = 1
                picture.timeOffset = 0
                picture.beginTime = 0
                picture.beginTime = picture.convertTime(CACurrentMediaTime(), from: nil) - paused
            } else {
                picture.timeOffset = picture.convertTime(CACurrentMediaTime(), from: nil)
                picture.speed = 0
            }
        }
    }

    func makeNSView(context: Context) -> Stage { Stage() }

    func updateNSView(_ stage: Stage, context: Context) { stage.take(self) }
}
