import OpenspotCore
import SwiftUI

enum PageTitle {
    case heading, header, hero

    var reveal: CGFloat {
        switch self {
        case .heading: SpotTokens.settingsHeadingReveal
        case .header: SpotTokens.settingsTitleReveal
        case .hero: SpotTokens.settingsHeroReveal
        }
    }
}
