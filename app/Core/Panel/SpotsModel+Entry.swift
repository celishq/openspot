import Foundation

extension SpotsModel {
    public struct Entry: Identifiable, Equatable {
        public enum Role: Sendable {
            case card
            case item
            case answer
            case command
            case action
        }

        public let id: String
        public let item: SpotItem?
        public let role: Role
        private let sizeChoice: SpotSize?
        private let defaultSize: SpotSize?
        private let run: SpotRun?
        private let fixedSpot: Spot
        private let fixedState: SpotState
        private let gridChoice: Bool?
        private let searchChoice: Bool?
        private let wordChoices: [String: String]
        public let cells: [Int: GridCell]

        public init(spot: Spot, run: SpotRun?, choice: SpotChoices = SpotChoices(), defaults: SpotChoices = SpotChoices(), isCore: Bool = false) {
            id = spot.id
            sizeChoice = choice.size(of: spot.id)
            defaultSize = defaults.size(of: spot.id)
            gridChoice = choice.isOnGrid(of: spot.id) ?? (isCore && !choice.names(spot.id) ? false : defaults.isOnGrid(of: spot.id))
            searchChoice = choice.isFound(of: spot.id) ?? defaults.isFound(of: spot.id)
            wordChoices = choice.commands(of: spot.id) ?? defaults.commands(of: spot.id) ?? [:]
            cells = choice.cells(of: spot.id) ?? defaults.cells(of: spot.id) ?? [:]
            item = nil
            role = .card
            self.run = run
            fixedSpot = spot
            fixedState = spot.headerState
        }

        public init(spot: Spot, item: SpotItem, role: Role = .item, detail: String? = nil) {
            id = "\(spot.id)\n\(item.run)"
            sizeChoice = item.card?.face.answerSize ?? .strip
            defaultSize = nil
            gridChoice = nil
            searchChoice = nil
            wordChoices = [:]
            cells = [:]
            self.item = item
            self.role = role
            run = nil
            fixedSpot = spot
            fixedState = item.card ?? SpotState(title: item.title, subtitle: role == .action ? detail : detail ?? (role == .answer ? item.subtitle ?? spot.name : item.path(in: spot)))
        }

        @MainActor public var commandWords: [(name: String, word: String)] {
            spot.triggers.commands.compactMap { name in
                let word = wordChoices[name] ?? name
                return word.isEmpty ? nil : (name, word)
            }
        }

        @MainActor public var spot: Spot {
            run?.spot ?? fixedSpot
        }

        public func cell(in grid: GridLayout) -> GridCell? {
            cells[grid.columns]
        }

        @MainActor public var size: SpotSize {
            let size = sizeChoice ?? defaultSize ?? spot.size
            return spot.fault != nil && size == .small ? .wide : size
        }

        @MainActor public var failure: String? {
            run?.failure
        }

        @MainActor public var isFound: Bool {
            (searchChoice ?? true) && spot.isFound
        }

        @MainActor public var isOnGrid: Bool {
            gridChoice ?? state.isOnGrid
        }

        @MainActor public var kind: SpotKind {
            item == nil ? spot.kind : .launch
        }

        @MainActor public var symbol: String {
            item?.symbol ?? spot.symbol
        }

        @MainActor public var showsHeaderPicture: Bool {
            item?.symbol == nil && (spot.fileIcon != nil || spot.glyph != nil)
        }

        @MainActor public var state: SpotState {
            run?.state ?? fixedState
        }

        @MainActor public var isOn: Bool {
            run?.isOn ?? (fixedState.active == true)
        }

        @MainActor public var isActive: Bool {
            isOn || act != nil
        }

        @MainActor public var shownState: SpotState {
            run?.shownState ?? fixedState
        }

        @MainActor public var act: ScriptCall? {
            run?.acts.first
        }

        @MainActor public var stopsOnPress: Bool {
            run?.cardAct != nil
        }

        @MainActor public var soleCommand: String? {
            kind == .list ? spot.soleCommand : nil
        }

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.id == rhs.id && lhs.item == rhs.item && lhs.sizeChoice == rhs.sizeChoice && lhs.gridChoice == rhs.gridChoice && lhs.cells == rhs.cells && lhs.defaultSize == rhs.defaultSize && lhs.role == rhs.role
                && lhs.run === rhs.run && lhs.fixedSpot == rhs.fixedSpot && lhs.fixedState == rhs.fixedState
        }
    }
}
