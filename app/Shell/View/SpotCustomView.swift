import OpenspotCore
import SwiftUI

/// A plugin's own view in its card, fed by the head of its last read. It draws only, and a press goes to the card (V5).
/// While it builds the place stays empty, and a view that fails shows why, shrunk to fit its place.
struct SpotCustomView: View {
    let source: String
    let values: [String: [String]]
    let size: CGSize
    let views: SpotViews
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .allowsHitTesting(false)
            .task(id: "\(source)\n\(isShown)") { await views.load(source) }
    }

    @ViewBuilder
    private var content: some View {
        switch views.phase(of: source) {
        case .building:
            Color.clear
        case .ready(let make):
            make(values, size, { _ in })
        case .failed(let reason):
            Text(reason)
                .font(SpotType.detail)
                .minimumScaleFactor(0.5)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        }
    }
}
