import Foundation

public protocol MacAccesses: Sendable {
    func status(of access: MacAccess) async -> ReadAccess
}
