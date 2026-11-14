import OpenspotCore
import SwiftUI

struct SpotFieldFocus: View {
    let model: SpotsModel
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onChange(of: model.isShown) { _, isShown in
                guard isShown else {
                    isFocused.wrappedValue = false
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeIn) {
                    if model.isShown, model.showsSearch, !model.isOpenForDrag { isFocused.wrappedValue = true }
                }
            }
            .onChange(of: model.showsSearch) { _, shows in
                isFocused.wrappedValue = shows
            }
            .onChange(of: model.isMenuOpen) { _, isOpen in
                if !isOpen, model.isShown, model.showsSearch { isFocused.wrappedValue = true }
            }
    }
}
