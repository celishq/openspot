import OpenspotCore
import SwiftUI

enum PageTitle {
    case heading, banner, header, hero

    static let linkURL = URL(string: "openspot-page:link")

    var reveal: CGFloat {
        switch self {
        case .heading: SpotTokens.settingsHeadingReveal
        case .banner: SpotTokens.settingsBannerReveal
        case .header: SpotTokens.settingsTitleReveal
        case .hero: SpotTokens.settingsCardReveal
        }
    }
}
