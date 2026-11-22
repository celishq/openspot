import OpenspotCore
import SwiftUI

struct NodeControl: View {
    let kind: String
    let part: SpotPart
    let look: SpotPart.Look?
    let size: CGSize
    var isCard = false
    var call: ScriptCall?
    var keepsIconColumn = false
    var recordingPart: String?
    var keys: KeyRecording?
    var focus: FocusState<String?>.Binding?
    var menuOpening: () -> SheetParts.MenuOpening? = { nil }
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    var onRecord: (SpotPart) -> Void = { _ in }

    var body: some View {
        switch kind {
        case BlockKind.toggle.word:
            NodeSwitch(part: part, look: look, size: size, isCard: isCard, call: call, keepsIconColumn: keepsIconColumn) { onSet(part, $0) }
        case BlockKind.choice.word:
            NodeChoice(part: part, look: look, size: size, isCard: isCard, call: call, keepsIconColumn: keepsIconColumn, menuOpening: menuOpening) { onSet(part, $0) }
        case BlockKind.field.word:
            NodeField(part: part, size: size, isCard: isCard, call: call, isRecording: recordingPart == part.id, keys: keys, focus: focus, onRecord: { onRecord(part) }) { onSet(part, $0) }
        case BlockKind.button.word:
            NodeButton(part: part, look: look, size: size, isCard: isCard, call: call, keepsIconColumn: keepsIconColumn) { onPress(part) }
        default:
            NodeNumber(part: part, look: look, size: size, isCard: isCard)
        }
    }
}
