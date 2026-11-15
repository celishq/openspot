import Foundation

enum SpotBlocking {
    static func run<Value: Sendable>(_ work: @escaping @Sendable () throws -> Value) async throws -> Value {
        try await withCheckedThrowingContinuation { answer in
            DispatchQueue.global(qos: .userInitiated).async { answer.resume(with: Result { try work() }) }
        }
    }
}
