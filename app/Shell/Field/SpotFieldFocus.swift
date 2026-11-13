import OpenspotCore
import SwiftUI

/// Gives the search field the focus when the panel shows with a search, when the keys come back to the search, and when the
/// actions menu closes, and takes it away when the panel hides. It alone reads whether the field keeps the keys, so that a
/// key in a form reruns this view and not the field.
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
