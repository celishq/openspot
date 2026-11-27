import SwiftUI

struct SpotRing: View {
    let fill: Double
    let line: CGFloat
    var colour: Color = SpotTheme.ink.color
    var track: Color = SpotTheme.ink.opacity(SpotTheme.track).color

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
