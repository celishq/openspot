import Foundation

public protocol MacScreen: Sendable {
    func devices() async -> [ScreenDevice]
    func shot(_ capture: ScreenCapture, in folder: URL) async throws -> URL?
    func startRecording(_ capture: ScreenCapture, in folder: URL) async throws
    func stopRecording() async throws -> ScreenRecording
    func recording() async throws -> ScreenRecording?
}
