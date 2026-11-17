import OpenspotCore
import SwiftUI

struct SpotThemeHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: SpotTokens.themeSpacing) {
            Text(title)
            Spacer(minLength: 0)
            trailing
        }
        .font(SpotType.strong)
        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        .modifier(SpotThemeBand())
    }
}

extension SpotThemeHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
