import Foundation
@testable import OpenspotCore

final class FakeClipboard: MacClipboard, MacEvents, @unchecked Sendable {
    private let lock = NSLock()
    private var textValue: String
    private var countValue = 0
    private var pasteValue = 0

    init(text: String = "") {
        textValue = text
    }

    func copy(_ text: String) {
        lock.withLock {
            textValue = text
            countValue += 1
        }
    }

    func copy(text: String) throws { copy(text) }
    func copy(file: URL) throws { copy(file.absoluteString) }
    func text() -> String { lock.withLock { textValue } }
    func paste() throws { lock.withLock { pasteValue += 1 } }

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {}
    var clipboardCount: Int { lock.withLock { countValue } }
    var pasteCount: Int { lock.withLock { pasteValue } }
    func measureLoad() -> LoadSample { LoadSample(busy: 0, total: 0, memory: 0) }
}
