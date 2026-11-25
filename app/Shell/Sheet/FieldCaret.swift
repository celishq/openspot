import AppKit

@MainActor
final class FieldCaret {
    static let shared = FieldCaret()

    private var armed: Date?
    private var token: NSObjectProtocol?

    func arm() {
        armed = Date()
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification, object: nil, queue: nil) { note in
            guard let text = note.object as? NSTextView else { return }
            MainActor.assumeIsolated { FieldCaret.shared.take(text) }
        }
    }

    private func take(_ text: NSTextView) {
        guard let armed, Date().timeIntervalSince(armed) < 0.5, text.isFieldEditor else { return }
        let end = NSRange(location: (text.string as NSString).length, length: 0)
        guard text.selectedRange() != end else { return }
        self.armed = nil
        text.setSelectedRange(end)
    }
}
