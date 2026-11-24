import AVKit
import OpenspotCore
import SwiftUI

struct SpotMedia: View {
    private static let pictures: Set<String> = ["png", "jpg", "jpeg", "gif"]
    private static let videos: Set<String> = ["mov", "mp4"]
    private static var edge: SpotRoundShape { SpotRoundShape(radius: SpotTokens.mediaRadius) }

    let source: String
    @State private var picture: NSImage?
    @State private var video: (player: AVPlayer, size: CGSize)?
    @State private var frames: PictureFrames?
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotMoves) private var moves
    @Environment(\.spotViewPlace) private var place

    private var kind: String {
        (URL(string: source)?.path ?? source).split(separator: ".").last.map { $0.lowercased() } ?? ""
    }

    var body: some View {
        if let frames {
            SpotMovingPicture(frames: frames, gravity: .resizeAspect, isPlaying: isShown && moves && place.cardsMove)
                .aspectRatio(frames.size, contentMode: .fit)
                .frame(maxWidth: frames.size.width)
                .clipShape(Self.edge)
        } else if let picture {
            Image(nsImage: picture)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: picture.size.width)
                .clipShape(Self.edge)
        } else if let video {
            VideoPlayer(player: video.player)
                .aspectRatio(video.size, contentMode: .fit)
                .frame(maxWidth: video.size.width)
                .clipShape(Self.edge)
        } else if WebPictures.isWeb(source), Self.videos.contains(kind), let url = URL(string: source) {
            Link(destination: url) { Label("Watch the video", systemImage: "play.rectangle") }
        } else {
            Color.clear
                .frame(height: 0)
                .task(id: source) { await load() }
        }
    }

    private func load() async {
        let kind = kind
        if PictureFrames.moves(source), let frames = await SpotPictureStore.shared.frames(SpotPictureStore.Key(path: source, changed: nil)) {
            self.frames = frames
        } else if Self.pictures.contains(kind), let path = await WebPictures.shared.path(of: source) {
            picture = await Task.detached(priority: .userInitiated) { NSImage(contentsOfFile: path) }.value
        } else if Self.videos.contains(kind), !WebPictures.isWeb(source) {
            let asset = AVURLAsset(url: URL(fileURLWithPath: source))
            guard let track = try? await asset.loadTracks(withMediaType: .video).first, let size = try? await track.load(.naturalSize), size.width > 0 else { return }
            video = (AVPlayer(playerItem: AVPlayerItem(asset: asset)), size)
        }
    }
}
