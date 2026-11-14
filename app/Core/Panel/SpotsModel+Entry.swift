import Foundation

extension SpotsModel {
    public struct Entry: Identifiable, Equatable {
        public let id: String
        public let item: SpotItem?
        public let isAnswer: Bool
        private let sizeChoice: SpotSize?
        private let defaultSize: SpotSize?
        private let run: SpotRun?
        private let fixedSpot: Spot
        private let fixedState: SpotState
        private let gridChoice: Bool?
        public let letter: CommandKey?
        public let panel: GridPanel

        public init(spot: Spot, run: SpotRun?, choice: SpotArrangement = SpotArrangement(), defaults: SpotArrangement = SpotArrangement(), letter: CommandKey? = nil) {
            id = spot.id
            sizeChoice = choice.size(of: spot.id)
            defaultSize = defaults.size(of: spot.id)
            gridChoice = choice.isOnGrid(of: spot.id) ?? defaults.isOnGrid(of: spot.id)
            panel = choice.panel(of: spot.id) ?? .center
            self.letter = letter
            item = nil
            isAnswer = false
            self.run = run
            fixedSpot = spot
            fixedState = spot.headerState
        }

        public init(spot: Spot, item: SpotItem, isAnswer: Bool = false) {
            id = "\(spot.id)\n\(item.run)"
            sizeChoice = item.card?.face.answerSize ?? .strip
            defaultSize = nil
            gridChoice = nil
            panel = .center
            letter = nil
            self.item = item
            self.isAnswer = isAnswer
            run = nil
            fixedSpot = spot
            fixedState = item.card ?? SpotState(title: item.title, subtitle: isAnswer ? item.subtitle ?? spot.name : item.path(in: spot))
        }

        @MainActor public var spot: Spot {
            run?.spot ?? fixedSpot
        }

        public var isSizeChosen: Bool {
            sizeChoice != nil
        }

        @MainActor public var size: SpotSize {
            let size = sizeChoice ?? defaultSize ?? spot.size
            return spot.fault != nil && size == .small ? .wide : size
        }

        @MainActor public var failure: String? {
            run?.failure
        }

        @MainActor public var isOnGrid: Bool {
            spot.offersCard && (gridChoice ?? state.isOnGrid)
        }

        @MainActor public var kind: SpotKind {
            item == nil ? spot.kind : .launch
        }

        @MainActor public var symbol: String {
            item?.symbol ?? spot.symbol
        }

        @MainActor public var showsHeaderPicture: Bool {
            item?.symbol == nil && (spot.icon != nil || spot.glyph != nil)
        }

        @MainActor public var state: SpotState {
            run?.state ?? fixedState
        }

        @MainActor public var isOn: Bool {
            run?.isOn ?? (fixedState.on == true)
        }

        @MainActor public var isActive: Bool {
            isOn || work != nil
        }

        @MainActor public var shownState: SpotState {
            run?.shownState ?? fixedState
        }

        @MainActor public var work: ScriptCall? {
            run?.work.first
        }

        @MainActor public var stopsOnPress: Bool {
            run?.cardWork != nil
        }

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.id == rhs.id && lhs.item == rhs.item && lhs.sizeChoice == rhs.sizeChoice && lhs.gridChoice == rhs.gridChoice && lhs.panel == rhs.panel
                && lhs.run === rhs.run && lhs.fixedSpot == rhs.fixedSpot && lhs.fixedState == rhs.fixedState
        }
    }
}
