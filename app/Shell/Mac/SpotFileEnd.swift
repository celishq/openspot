import AVFoundation
import ScreenCaptureKit

final class SpotFileEnd: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let onStart: @Sendable () -> Void
    private var result: Result<Void, Error>?
    private var waiters: [CheckedContinuation<Void, Error>] = []

    init(onStart: @escaping @Sendable () -> Void = {}) {
        self.onStart = onStart
    }

    func wait() async throws {
        try await withCheckedThrowingContinuation { (waiter: CheckedContinuation<Void, Error>) in
            lock.lock()
            defer { lock.unlock() }
            if let result {
                waiter.resume(with: result)
            } else {
                waiters.append(waiter)
            }
        }
    }

    private func end(_ result: Result<Void, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard self.result == nil else { return }
        self.result = result
        waiters.forEach { $0.resume(with: result) }
        waiters = []
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        end(.failure(error))
    }

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        onStart()
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        end(.success(()))
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        end(.failure(error))
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        let whole = ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? (error == nil)
        end(whole ? .success(()) : .failure(error!))
    }
}
