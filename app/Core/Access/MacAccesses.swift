import Foundation

public protocol MacAccesses: Sendable {
    func status(of access: MacAccess) async -> ReadAccess
    func ask(for access: MacAccess) async
}

extension MacAccesses {
    public func ask(for access: MacAccess) async {}
}
