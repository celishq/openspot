import OpenspotCore
import SwiftUI

struct SettingMenuOpening: View {
    let model: SpotsModel
    let item: SpotMenuAnchor.Item?

    var body: some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: model.settingMenu?.serial) {
                guard let menu = model.settingMenu, let item else { return }
                let row = proxy[item.bounds]
                let place = proxy.frame(in: .global)
                let rect = row.offsetBy(dx: place.minX, dy: place.minY)
                DispatchQueue.main.async {
                    SpotChoiceMenu.popUp(options: menu.options, value: menu.value, atEndOf: rect) { [weak model] in model?.chooseSetting($0, in: menu) }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
