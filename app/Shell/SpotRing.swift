import SwiftUI

/// A round gauge: a faint track, with an arc over it that starts at the top. It fills the room it gets.
struct SpotRing: View {
    let fill: Double
    let line: CGFloat
    var colour = SpotTheme.ink
    var track = SpotTheme.ink.opacity(SpotTheme.track)

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: line)
            Circle()
                .trim(from: 0, to: fill)
                .rotation(.degrees(-90))
                .stroke(colour, style: StrokeStyle(lineWidth: line, lineCap: .round))
        }
        .padding(line / 2)
    }
}
