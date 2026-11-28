import EventKit
import OpenspotCore

extension CalendarAccess {
    init(of entity: EKEntityType) {
        switch EKEventStore.authorizationStatus(for: entity) {
        case .fullAccess: self = .allowed
        case .notDetermined: self = .unasked
        default: self = .denied
        }
    }
}
