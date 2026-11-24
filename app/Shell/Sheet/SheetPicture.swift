import OpenspotCore
import SwiftUI

struct SheetPicture: View {
    let arrived: SpotPictureStore.Key
    @State private var followed: (from: SpotPictureStore.Key, changed: Double?)?
    @State private var loaded: (key: SpotPictureStore.Key, image: CGImage)?
    @State private var moving: (key: SpotPictureStore.Key, frames: PictureFrames)?
    @Environment(\.spotIsHeld) private var isHeld
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotMoves) private var moves

    private var key: SpotPictureStore.Key {
        followed.flatMap { $0.from == arrived ? SpotPictureStore.Key(path: arrived.path, changed: $0.changed) : nil } ?? arrived
    }

    var body: some View {
        let key = key
        Color.clear
            .overlay {
                if PictureFrames.moves(key.path), let frames = SpotPictureStore.shared.cachedFrames(key) ?? (moving?.key == key ? moving?.frames : nil) {
                    SpotMovingPicture(frames: frames, gravity: .resizeAspectFill, isPlaying: isShown && moves && !isHeld)
                } else if let image = SpotPictureStore.shared.cached(key) ?? (loaded?.key == key ? loaded?.image : nil) {
                    Image(decorative: image, scale: SpotTokens.pictureScale).resizable().scaledToFill()
                } else {
                    SpotTheme.ink.opacity(SpotTheme.fill)
                }
            }
            .task(id: key) {
                guard !isHeld else { return }
                if PictureFrames.moves(key.path), let frames = await SpotPictureStore.shared.frames(key) {
                    moving = (key, frames)
                } else if let image = await SpotPictureStore.shared.image(key) {
                    loaded = (key, image)
                }
            }
            .task(id: arrived) {
                guard !isHeld else { return }
                for await changed in PictureFile(path: arrived.path).changes { followed = (arrived, changed) }
            }
    }
}
