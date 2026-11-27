import Foundation
@testable import OpenspotCore

final class FakeAccesses: MacAccesses, @unchecked Sendable {
    private let lock = NSLock()
    private var statusValues: [MacAccess: AccessStatus]
    private var readValues: [MacAccess] = []

    init(_ statuses: [MacAccess: AccessStatus] = [:]) {
        statusValues = statuses
    }

    private var askValues: [MacAccess] = []

    var reads: [MacAccess] { lock.withLock { readValues } }
    var asks: [MacAccess] { lock.withLock { askValues } }

    func ask(for access: MacAccess) async {
        lock.withLock { askValues.append(access) }
    }

    func set(_ access: MacAccess, to status: AccessStatus) {
        lock.withLock { statusValues[access] = status }
    }

    func status(of access: MacAccess) async -> AccessStatus {
        lock.withLock {
            readValues.append(access)
            return statusValues[access] ?? .allowed
        }
    }
}
