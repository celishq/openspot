import OpenspotCore
import SwiftUI

struct SpotThemeLine<Title: View>: View {
    let symbol: String
    var trailing = ""
    var isChosen = false
    var isDimmed = false
    @ViewBuilder let title: Title

    var body: some View {
        HStack(spacing: SpotTokens.themeRowPadding) {
            Image(systemName: symbol)
                .font(SpotType.rowIcon)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                .frame(width: SpotTokens.themeIconWidth)
            title
                .font(SpotType.builtIn.body)
                .foregroundStyle(SpotTheme.ink.opacity(isDimmed ? SpotTheme.secondaryLight : 1))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(trailing)
                .font(SpotType.builtIn.detail)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        }
        .modifier(SpotThemeBand(isChosen: isChosen))
    }
}
