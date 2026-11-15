import SwiftUI

/// The last screen of the game. It fills an area that is about square or wider, such as a card, and cuts the edges; in a
/// taller area, such as a sheet, it shows the whole screen. The picture loads off `body`, once per file.
struct SpotView: View {
    let spot: SpotInput
    @State private var picture: NSImage?

    private var fills: Bool {
        spot.size.width >= spot.size.height * 0.9
    }

    var body: some View {
        ZStack {
            Color.clear
            if let picture {
                Image(nsImage: picture)
                    .resizable()
                    .aspectRatio(contentMode: fills ? .fill : .fit)
                    .frame(width: spot.size.width, height: spot.size.height)
                    .clipped()
            }
        }
        .task(id: spot["picture"]) {
            let path = spot["picture"]
            picture = await Task.detached { path.flatMap(NSImage.init(contentsOfFile:)) }.value
        }
    }
}
