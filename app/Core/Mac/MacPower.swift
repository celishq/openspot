import Foundation

public protocol MacPower: Sendable {
    func holdLidClosed() async throws
    func releaseLidClosed() async
    func sample() async throws -> Data
}
