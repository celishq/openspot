import OpenspotCore
import SwiftUI

extension NodeContext {
    var isCard: Bool {
        variants.contains(.card)
    }

    @MainActor func set(_ part: SpotPart, to value: String) {
        if isCard { actions.slot(part.id, value) } else { actions.set(part, to: value) }
    }

    @MainActor func press(_ part: SpotPart) {
        if isCard { actions.slot(part.id, nil) } else { actions.press(part) }
    }

    @MainActor func call(of part: SpotPart) -> ScriptCall? {
        isCard ? nil : actions.act(of: part)
    }

    @MainActor func keepsIconColumn(_ part: SpotPart) -> Bool {
        panel?.keepsIconColumn(part) == true
    }
}
