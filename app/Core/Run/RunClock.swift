import Foundation

public struct RunClock: Sendable {
    public let now: @Sendable () -> Date
    public let sleep: @MainActor @Sendable (Duration, Duration?) async throws -> Void
    public let after: @Sendable (TimeInterval, @escaping @Sendable () -> Void) -> Void
    public let threadTime: @Sendable () -> TimeInterval

    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @MainActor @Sendable (Duration, Duration?) async throws -> Void = { try await Task.sleep(for: $0, tolerance: $1) },
        after: @escaping @Sendable (TimeInterval, @escaping @Sendable () -> Void) -> Void = { DispatchQueue.global().asyncAfter(deadline: .now() + max(0, $0), execute: $1) },
        threadTime: @escaping @Sendable () -> TimeInterval = RunClock.cpuOfThread
    ) {
        self.now = now
        self.sleep = sleep
        self.after = after
        self.threadTime = threadTime
    }

    public static func cpuOfThread() -> TimeInterval {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { thread_info(pthread_mach_thread_np(pthread_self()), thread_flavor_t(THREAD_BASIC_INFO), $0, &count) }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000
        return user + Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000
    }
}
