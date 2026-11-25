import ApplicationServices
import AVFoundation
import CoreGraphics
import EventKit
import IOKit.hid
import OpenspotCore
import ServiceManagement

struct SpotAccesses: MacAccesses {
    func status(of access: MacAccess) async -> ReadAccess {
        switch access {
        case .accessibility: AXIsProcessTrusted() ? .allowed : .unasked
        case .automation: .unknown
        case .screen: CGPreflightScreenCaptureAccess() ? .allowed : .denied
        case .calendars: Self.status(of: .event)
        case .reminders: Self.status(of: .reminder)
        case .camera: Self.status(of: .video)
        case .microphone: Self.status(of: .audio)
        case .input: Self.input()
        case .helper: Self.helper()
        }
    }

    private static func status(of entity: EKEntityType) -> ReadAccess {
        switch EKEventStore.authorizationStatus(for: entity) {
        case .fullAccess: .allowed
        case .notDetermined: .unasked
        default: .denied
        }
    }

    private static func status(of media: AVMediaType) -> ReadAccess {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: .allowed
        case .notDetermined: .unasked
        default: .denied
        }
    }

    private static func input() -> ReadAccess {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: .allowed
        case kIOHIDAccessTypeDenied: .denied
        default: .unasked
        }
    }

    private static func helper() -> ReadAccess {
        guard let daemon = PowerDaemon.readForApp() else { return .unknown }
        return switch SMAppService.daemon(plistName: daemon.plist).status {
        case .enabled: .allowed
        case .requiresApproval: .denied
        case .notRegistered: .unasked
        default: .unknown
        }
    }
}
