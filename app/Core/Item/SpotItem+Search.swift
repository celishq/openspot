import Foundation

extension SpotItem {
    var searchText: SearchText {
        SearchText(title: title, subtitle: subtitle, keywords: keywords, glyph: glyph)
    }
}
