import Foundation
@testable import OpenspotCore

final class SpotFrames: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [String] = []
    private var isOver = false

    init(_ stream: AsyncThrowingStream<String, Error>) {
        Task { [weak self] in
            do {
                for try await frame in stream { self?.take(frame) }
            } catch {}
            self?.finish()
        }
    }

    var all: [String] {
        lock.withLock { seen }
    }

    var ended: Bool {
        lock.withLock { isOver }
    }

    var ends: [String] {
        all.compactMap { FrameRoot(text: $0).end }
    }

    var toasts: [String] {
        all.compactMap { SpotOutput(text: $0).toast }
    }

    private func take(_ frame: String) {
        lock.withLock { seen.append(frame) }
    }

    private func finish() {
        lock.withLock { isOver = true }
    }
}
