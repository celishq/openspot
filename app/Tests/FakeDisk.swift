import Foundation
import os
@testable import OpenspotCore

final class FakeDisk: ConfigDisk {
    private struct State {
        var text: String?
        var version = 0
        var reads = 0
        var writes = 0
        var fails = false
    }

    private let state: OSAllocatedUnfairLock<State>

    init(text: String? = nil) {
        state = OSAllocatedUnfairLock(initialState: State(text: text))
    }

    var text: String? {
        state.withLock { $0.text }
    }

    var reads: Int {
        state.withLock { $0.reads }
    }

    var writes: Int {
        state.withLock { $0.writes }
    }

    func put(_ text: String) {
        state.withLock {
            $0.text = text
            $0.version += 1
        }
    }

    func fail(_ fails: Bool) {
        state.withLock { $0.fails = fails }
    }

    func read(_ url: URL) -> String? {
        state.withLock {
            $0.reads += 1
            return $0.text
        }
    }

    func write(_ text: String, to url: URL) throws {
        try state.withLock {
            if $0.fails { throw CocoaError(.fileWriteNoPermission) }
            $0.text = text
            $0.version += 1
            $0.writes += 1
        }
    }

    func readStamp(of url: URL) -> String {
        state.withLock { String($0.version) }
    }
}
