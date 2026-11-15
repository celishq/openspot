import Foundation

public struct ProcessTime: Equatable, Sendable {
    public static let zero = ProcessTime(cpu: 0, wakeups: 0)

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

    init?(of id: pid_t) {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(id, RUSAGE_INFO_V2, $0) }
        }
        guard result == 0 else { return nil }
        let ticks = info.ri_user_time + info.ri_system_time + info.ri_child_user_time + info.ri_child_system_time
        cpu = Double(ticks) * Self.nanosecondsPerTick / 1_000_000_000
        wakeups = info.ri_pkg_idle_wkups + info.ri_interrupt_wkups + info.ri_child_pkg_idle_wkups + info.ri_child_interrupt_wkups
        read = info.ri_diskio_bytesread
        written = info.ri_diskio_byteswritten
    }

    init(_ usage: rusage) {
        cpu = Self.seconds(usage.ru_utime) + Self.seconds(usage.ru_stime)
        wakeups = 0
        read = 0
        written = 0
    }

    func since(_ earlier: ProcessTime) -> ProcessTime {
        ProcessTime(cpu: max(cpu - earlier.cpu, 0), wakeups: wakeups &- min(earlier.wakeups, wakeups), read: read &- min(earlier.read, read), written: written &- min(earlier.written, written))
    }

    public static func + (left: ProcessTime, right: ProcessTime) -> ProcessTime {
        ProcessTime(cpu: left.cpu + right.cpu, wakeups: left.wakeups + right.wakeups, read: left.read + right.read, written: left.written + right.written)
    }

    private static let nanosecondsPerTick: Double = {
        var base = mach_timebase_info_data_t()
        mach_timebase_info(&base)
        return Double(base.numer) / Double(base.denom)
    }()

    private static func seconds(_ time: timeval) -> TimeInterval {
        Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000
    }
}
