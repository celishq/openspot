import Foundation
@testable import OpenspotCore

final class FakeClipboard: MacClipboard, MacEvents, @unchecked Sendable {
    private let lock = NSLock()
    private var textValue: String
    private var contentsValue = ClipboardContents.text
    private var imageValue = Data()
    private var countValue = 0
    private var pasteValue = 0

    init(text: String = "") {
        textValue = text
    }

    func copy(_ text: String) {
        lock.withLock {
            textValue = text
            contentsValue = .text
            countValue += 1
        }
    }

    func copy(files: [URL]) {
        lock.withLock {
            contentsValue = .files(files)
            countValue += 1
        }
    }

    func copy(image: Data, kind: String) {
        lock.withLock {
            imageValue = image
            contentsValue = .image(kind)
            countValue += 1
        }
    }

    func copy(concealed text: String) {
        lock.withLock {
            textValue = text
            contentsValue = .none
            countValue += 1
        }
    }

    func copy(text: String) throws { copy(text) }
    func copy(file: URL) throws { copy(file.absoluteString) }
    func text() -> String { lock.withLock { textValue } }
    func contents() -> ClipboardContents { lock.withLock { contentsValue } }
    func count() -> Int { lock.withLock { countValue } }
    func writeImage(to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lock.withLock { imageValue }.write(to: file)
    }
    func paste() throws { lock.withLock { pasteValue += 1 } }

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {}
    var clipboardCount: Int { lock.withLock { countValue } }
    var pasteCount: Int { lock.withLock { pasteValue } }
    func measureLoad() -> LoadSample { LoadSample(busy: 0, total: 0, memory: 0) }
}
