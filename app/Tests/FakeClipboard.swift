import Foundation
@testable import OpenspotCore

final class FakeClipboard: MacClipboard, MacEvents, @unchecked Sendable {
    private let lock = NSLock()
    private var textValue = ""
    private var countValue = 0

    func copy(_ text: String) {
        lock.withLock {
            textValue = text
            countValue += 1
        }
    }

    func copy(text: String) throws { copy(text) }
    func copy(file: URL) throws { copy(file.absoluteString) }
    func text() -> String { lock.withLock { textValue } }
    func paste() throws {}

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {}
    var clipboardCount: Int { lock.withLock { countValue } }
    func measureLoad() -> LoadSample { LoadSample(busy: 0, total: 0, memory: 0) }
}
