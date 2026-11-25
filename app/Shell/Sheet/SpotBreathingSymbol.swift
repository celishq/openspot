import SwiftUI

struct SpotBreathingSymbol: View {
    let name: String
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotMoves) private var moves

    var body: some View {
        Image(systemName: name)
            .symbolEffect(.breathe.pulse.byLayer, options: .repeating, isActive: isShown && moves)
    }
}
