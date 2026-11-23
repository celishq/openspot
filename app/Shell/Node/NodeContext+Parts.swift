import OpenspotCore
import SwiftUI

extension NodeContext {
    var isCard: Bool {
        variants.contains(.card)
    }

    @MainActor func set(_ part: SpotPart, to value: String) {
        if isCard { host.slot(part.id, value) } else { host.set(part, to: value) }
    }

    @MainActor func press(_ part: SpotPart) {
        if isCard { host.slot(part.id, nil) } else { host.press(part) }
    }

    @MainActor func call(of part: SpotPart) -> ScriptCall? {
        isCard ? nil : host.act(of: part)
    }

    @MainActor func keepsIconColumn(_ part: SpotPart) -> Bool {
        panel?.keepsIconColumn(part) == true
    }
}
