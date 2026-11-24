import Foundation
@testable import OpenspotCore

final class FakeClipboard: MacClipboard, MacEvents, @unchecked Sendable {
    private let lock = NSLock()
    private var textValue: String
    private var typesValue: Set<String> = [ClipboardContents.textType]
    private var filesValue: [URL] = []
    private var imageValue = Data()
    private var countValue = 0
    private var readsValue = 0
    private var pasteValue = 0

    init(text: String = "") {
        textValue = text
    }

    func copy(_ text: String) {
        lock.withLock {
            textValue = text
            typesValue = [ClipboardContents.textType]
            filesValue = []
            countValue += 1
        }
    }

    func copy(files: [URL]) {
        lock.withLock {
            typesValue = ["public.file-url", ClipboardContents.textType]
            filesValue = files
            countValue += 1
        }
    }

    func copy(image: Data, kind: String) {
        lock.withLock {
            imageValue = image
            typesValue = [kind == "png" ? ClipboardContents.pngType : ClipboardContents.tiffType]
            filesValue = []
            countValue += 1
        }
    }

    func copy(concealed text: String) {
        lock.withLock {
            textValue = text
            typesValue = [ClipboardContents.concealedType, ClipboardContents.textType]
            filesValue = []
            countValue += 1
        }
    }

    func copy(text: String) throws { copy(text) }
    func copy(file: URL) throws { copy(file.absoluteString) }
    func text() -> String {
        lock.withLock {
            readsValue += 1
            return textValue
        }
    }
    var textReads: Int { lock.withLock { readsValue } }
    func types() -> Set<String> { lock.withLock { typesValue } }
    func files() -> [URL] { lock.withLock { filesValue } }
    func count() -> Int { lock.withLock { countValue } }
    func image() -> Data? {
        lock.withLock {
            guard typesValue.contains(ClipboardContents.pngType) || typesValue.contains(ClipboardContents.tiffType) else { return nil }
            return imageValue
        }
    }
    func paste() throws { lock.withLock { pasteValue += 1 } }

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {}
    var clipboardCount: Int { lock.withLock { countValue } }
    var pasteCount: Int { lock.withLock { pasteValue } }
    func measureLoad() -> LoadSample { LoadSample(busy: 0, total: 0, memory: 0) }
}
