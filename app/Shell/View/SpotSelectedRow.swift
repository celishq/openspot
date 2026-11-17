import SwiftUI

struct SpotSelectedRow<Content: View>: View {
    let run: () -> String?
    @ViewBuilder let content: (String?) -> Content

    var body: some View {
        content(run())
    }
}
