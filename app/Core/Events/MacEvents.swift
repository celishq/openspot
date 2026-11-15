import Foundation

public protocol MacEvents: AnyObject, Sendable {
    @MainActor func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void)
    @MainActor var clipboardCount: Int { get }
}
