import Foundation

/// The CPU time, user and system, and the wakeups of a process, with those of each child that it waited for, and the bytes
/// that the process itself read from and wrote to the disk.
public struct ProcessTime: Equatable, Sendable {
    public static let zero = ProcessTime(cpu: 0, wakeups: 0)

    /// The CPU time in seconds.
    public var cpu: TimeInterval
    public var wakeups: UInt64
    public var read: UInt64
    public var written: UInt64

    public init(cpu: TimeInterval, wakeups: UInt64, read: UInt64 = 0, written: UInt64 = 0) {
        self.cpu = cpu
        self.wakeups = wakeups
        self.read = read
        self.written = written
    }

    /// The time of a process that runs, or that ended and is not reaped yet, or nil when there is none.
    init?(of id: pid_t) {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(id, RUSAGE_INFO_V2, $0) }
        }
        guard result == 0 else { return nil }
        let ticks = info.ri_user_time + info.ri_system_time + info.ri_child_user_time + info.ri_child_system_time
        cpu = Double(ticks) * Self.nanoseconds / 1_000_000_000
        wakeups = info.ri_pkg_idle_wkups + info.ri_interrupt_wkups + info.ri_child_pkg_idle_wkups + info.ri_child_interrupt_wkups
        read = info.ri_diskio_bytesread
        written = info.ri_diskio_byteswritten
    }

    /// The time of a process that `wait4` reaped, which counts no wakeups.
    init(_ usage: rusage) {
        cpu = Self.seconds(usage.ru_utime) + Self.seconds(usage.ru_stime)
        wakeups = 0
        read = 0
        written = 0
    }

    public static func + (left: ProcessTime, right: ProcessTime) -> ProcessTime {
        ProcessTime(cpu: left.cpu + right.cpu, wakeups: left.wakeups + right.wakeups, read: left.read + right.read, written: left.written + right.written)
    }

    /// The nanoseconds in one tick of the clock that `proc_pid_rusage` counts in.
    private static let nanoseconds: Double = {
        var base = mach_timebase_info_data_t()
        mach_timebase_info(&base)
        return Double(base.numer) / Double(base.denom)
    }()

    private static func seconds(_ time: timeval) -> TimeInterval {
        Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000
    }
}
