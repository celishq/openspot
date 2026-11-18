import Foundation
@testable import OpenspotCore

enum TestSettings {
    @TaskLocal static var values: [String: String] = [:]

    static var text: String {
        TextBlock(fields: values.sorted { $0.key < $1.key }.map { .init(key: "setting.\($0.key)", value: $0.value) }).text
    }

    static func with<T>(_ values: [String: String], isolation: isolated (any Actor)? = #isolation, _ body: () async throws -> T) async rethrows -> T {
        try await $values.withValue(values) { try await body() }
    }
}
