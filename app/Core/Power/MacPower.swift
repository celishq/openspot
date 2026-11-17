import Foundation

public protocol MacPower: Sendable {
    func holdLidClosed(during hold: @escaping @Sendable () async -> Void) async throws
    func sample() async throws -> Data
}
