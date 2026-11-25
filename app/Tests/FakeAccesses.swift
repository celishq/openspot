import Foundation
@testable import OpenspotCore

final class FakeAccesses: MacAccesses, @unchecked Sendable {
    private let lock = NSLock()
    private var statusValues: [MacAccess: ReadAccess]
    private var readValues: [MacAccess] = []

    init(_ statuses: [MacAccess: ReadAccess] = [:]) {
        statusValues = statuses
    }

    var reads: [MacAccess] { lock.withLock { readValues } }

    func set(_ access: MacAccess, to status: ReadAccess) {
        lock.withLock { statusValues[access] = status }
    }

    func status(of access: MacAccess) async -> ReadAccess {
        lock.withLock {
            readValues.append(access)
            return statusValues[access] ?? .allowed
        }
    }
}
