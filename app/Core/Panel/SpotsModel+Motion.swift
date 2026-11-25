import Foundation

extension SpotsModel {
    public func toggleSlowMotion() {
        toast(ToastNote(words: MotionTokens.toggleSlowMotion() ? "Slow motion on" : "Slow motion off"))
    }

    public func slowMotion(_ isOn: Bool?) -> Bool {
        if let isOn, isOn != MotionTokens.isSlow { toggleSlowMotion() }
        return MotionTokens.isSlow
    }
}
