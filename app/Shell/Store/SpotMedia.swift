import AVKit
import OpenspotCore
import SwiftUI

struct SpotMedia: View {
    private static let pictures: Set<String> = ["png", "jpg", "jpeg"]
    private static let videos: Set<String> = ["mov", "mp4"]
    private static let edge = SpotRoundShape(radius: 8)

    let source: String
    @State private var picture: NSImage?
    @State private var video: (player: AVPlayer, size: CGSize)?

    private var kind: String {
        (URL(string: source)?.path ?? source).split(separator: ".").last.map { $0.lowercased() } ?? ""
    }

    var body: some View {
        if let picture {
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
        if Self.pictures.contains(kind), let path = await WebPictures.shared.path(of: source) {
            picture = await Task.detached(priority: .userInitiated) { NSImage(contentsOfFile: path) }.value
        } else if Self.videos.contains(kind), !WebPictures.isWeb(source) {
            let asset = AVURLAsset(url: URL(fileURLWithPath: source))
            guard let track = try? await asset.loadTracks(withMediaType: .video).first, let size = try? await track.load(.naturalSize), size.width > 0 else { return }
            video = (AVPlayer(playerItem: AVPlayerItem(asset: asset)), size)
        }
    }
}
