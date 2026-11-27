import OpenspotCore
import SwiftUI

struct PageToolbarTitle: View {
    let scroll: PageScroll
    let title: String

    var body: some View {
        Text(title)
            .font(SpotType.settingsPageTitle)
            .lineLimit(1)
            .opacity(scroll.isTitleShown ? 1 : MotionTokens.hiddenOpacity)
            .allowsHitTesting(scroll.isTitleShown)
    }
}
