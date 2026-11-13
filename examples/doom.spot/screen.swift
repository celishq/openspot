import SwiftUI

/// The last screen of the game. It fills an area that is about square or wider, such as a card, and cuts the edges; in a
/// taller area, such as a sheet, it shows the whole screen.
struct SpotView: View {
    let spot: SpotInput

    private var fills: Bool {
        spot.size.width >= spot.size.height * 0.9
    }

    var body: some View {
        if let path = spot["picture"], let picture = NSImage(contentsOfFile: path) {
            Image(nsImage: picture)
                .resizable()
                .aspectRatio(contentMode: fills ? .fill : .fit)
                .frame(width: spot.size.width, height: spot.size.height)
                .clipped()
        }
    }
}
