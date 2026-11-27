import Foundation

public protocol MacEvents: AnyObject, Sendable {
    @MainActor func listen(_ heard: @escaping @MainActor (AppSignal) -> Void)
    @MainActor var clipboardCount: Int { get }
    @MainActor var idleSeconds: TimeInterval { get }
    @MainActor func measureLoad() -> LoadSample
}
