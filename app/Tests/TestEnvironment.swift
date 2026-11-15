import Foundation

enum TestEnvironment {
    @TaskLocal static var values = ProcessInfo.processInfo.environment

    static func with<T>(_ changes: [String: String?], isolation: isolated (any Actor)? = #isolation, _ body: () async throws -> T) async rethrows -> T {
        var changed = values
        for (name, value) in changes { changed[name] = value }
        return try await $values.withValue(changed) { try await body() }
    }
}
