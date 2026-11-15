import Foundation

public struct UnlockPass: Sendable {
    public static let reuse: TimeInterval = 300

    private var passed: [String: Date] = [:]

    public init() {}

    public func covers(_ act: String, at now: Date) -> Bool {
        passed[act].map { now.timeIntervalSince($0) < Self.reuse } ?? false
    }

    public mutating func pass(_ act: String, at now: Date) {
        passed = passed.filter { now.timeIntervalSince($0.value) < Self.reuse }
        passed[act] = now
    }
}
