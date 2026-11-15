import Foundation

public protocol MacWindows: Sendable {
    func frame() async throws -> WindowFrame
    func move(_ move: WindowMove) async throws
}
