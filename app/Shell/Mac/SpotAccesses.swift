import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import EventKit
import IOKit.hid
import OpenspotCore
import ServiceManagement

struct SpotAccesses: MacAccesses {
    func status(of access: MacAccess) async -> AccessStatus {
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

    func ask(for access: MacAccess) async {
        let isUnasked = await status(of: access) == .unasked
        switch access {
        case .accessibility:
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .screen:
            _ = CGRequestScreenCaptureAccess()
            await Self.open(access)
        case .calendars where isUnasked:
            _ = try? await EKEventStore().requestFullAccessToEvents()
        case .reminders where isUnasked:
            _ = try? await EKEventStore().requestFullAccessToReminders()
        case .camera where isUnasked:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        case .microphone where isUnasked:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .input where isUnasked:
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        default:
            await Self.open(access)
        }
    }

    @MainActor
    private static func open(_ access: MacAccess) {
        if let pane = access.pane { NSWorkspace.shared.open(pane) }
    }

    private static func status(of entity: EKEntityType) -> AccessStatus {
        switch EKEventStore.authorizationStatus(for: entity) {
        case .fullAccess: .allowed
        case .notDetermined: .unasked
        default: .denied
        }
    }

    private static func status(of media: AVMediaType) -> AccessStatus {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: .allowed
        case .notDetermined: .unasked
        default: .denied
        }
    }

    private static func input() -> AccessStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: .allowed
        case kIOHIDAccessTypeDenied: .denied
        default: .unasked
        }
    }

    private static func helper() -> AccessStatus {
        guard let daemon = PowerDaemon.readForApp() else { return .unknown }
        return switch SMAppService.daemon(plistName: daemon.plist).status {
        case .enabled: .allowed
        case .requiresApproval: .denied
        case .notRegistered: .unasked
        default: .unknown
        }
    }
}
