import AppKit
import IOKit
import IOKit.ps
import OpenspotCore

@MainActor
final class SpotSystemEvents {
    private var heard: (@MainActor (SpotEvent) -> Void)?
    private var power: String?
    private var powerSource: CFRunLoopSource?
    private var devicePort: IONotificationPortRef?
    private var deviceWatch: io_iterator_t = 0
    private var mounts: NSObjectProtocol?
    private static let host = mach_host_self()

    static func measureLoad() -> LoadSample {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
        }
        var free: Int32 = 100
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_level", &free, &size, nil, 0)
        guard result == KERN_SUCCESS else { return LoadSample(busy: 0, total: 0, memory: Int(100 - free)) }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3].map(UInt64.init)
        let idle = ticks[Int(CPU_STATE_IDLE)]
        let total = ticks.reduce(0, +)
        return LoadSample(busy: total - idle, total: total, memory: Int(100 - free))
    }

    func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void) {
        stop()
        self.heard = heard
        power = Self.readPowerSource()
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let events = Unmanaged<SpotSystemEvents>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { events.powerChanged() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        mounts = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { note in
            let path = (note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL)?.path
            MainActor.assumeIsolated { heard(.named(SpotEvent.diskMount, value: path)) }
        }
        watchDevices(context)
    }

    private func watchDevices(_ context: UnsafeMutableRawPointer) {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        devicePort = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
        let result = IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOUSBHostDevice"), { context, iterator in
            guard let context else { return }
            let events = Unmanaged<SpotSystemEvents>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { events.devicesConnected(iterator, tells: true) }
        }, context, &deviceWatch)
        if result == KERN_SUCCESS { devicesConnected(deviceWatch, tells: false) }
    }

    private func devicesConnected(_ iterator: io_iterator_t, tells: Bool) {
        while case let device = IOIteratorNext(iterator), device != 0 {
            let name = IORegistryEntryCreateCFProperty(device, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            IOObjectRelease(device)
            if tells { heard?(.named(SpotEvent.deviceConnect, value: name)) }
        }
    }

    private func powerChanged() {
        let next = Self.readPowerSource()
        guard next != power else { return }
        power = next
        heard?(.named(SpotEvent.powerChange, value: next))
    }

    private static func readPowerSource() -> String {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? else { return "ac" }
        switch type {
        case kIOPMBatteryPowerKey: return "battery"
        case kIOPMUPSPowerKey: return "ups"
        default: return "ac"
        }
    }

    private func stop() {
        if let mounts { NSWorkspace.shared.notificationCenter.removeObserver(mounts) }
        mounts = nil
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
        powerSource = nil
        if deviceWatch != 0 { IOObjectRelease(deviceWatch) }
        deviceWatch = 0
        if let devicePort { IONotificationPortDestroy(devicePort) }
        devicePort = nil
    }
}
