import Foundation

/// A call that blocks its thread, such as a wait for a helper or for another app's Accessibility answer. It runs on a
/// thread of GCD, so that it holds no thread of Swift's own pool, which every other call of the app shares.
enum SpotBlocking {
    static func run<Value: Sendable>(_ work: @escaping @Sendable () throws -> Value) async throws -> Value {
        try await withCheckedThrowingContinuation { answer in
            DispatchQueue.global(qos: .userInitiated).async { answer.resume(with: Result { try work() }) }
        }
    }
}
