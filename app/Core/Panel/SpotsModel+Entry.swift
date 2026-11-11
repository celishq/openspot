import Foundation

/// The cards of the model.
extension SpotsModel {
    /// One card: a script, a widget, or a row that the main search found. It holds which card it is and the person's
    /// choices. Its state, its size and its place on the grid come live from its run, so two equal entries can show different
    /// things, and the model lays out the grid again on each change that a run reports.
    public struct Entry: Identifiable, Equatable {
        public let id: String
        public let item: SpotItem?
        /// Whether its row is an answer of its spot to the text of the main search (A3).
        public let isAnswer: Bool
        private let sizeChoice: SpotSize?
        private let run: SpotRun?
        private let fixedSpot: Spot
        private let fixedState: SpotState
        private let gridChoice: Bool?
        /// The letter that runs it from the panel, which the person or the default config gives it.
        public let letter: CommandKey?

        public init(spot: Spot, run: SpotRun?, choice: SpotArrangement = SpotArrangement(), defaults: SpotArrangement = SpotArrangement(), letter: CommandKey? = nil) {
            id = spot.id
            sizeChoice = choice.size(of: spot.id)
            gridChoice = choice.isOnGrid(of: spot.id) ?? defaults.isOnGrid(of: spot.id)
            self.letter = letter
            item = nil
            isAnswer = false
            self.run = run
            fixedSpot = spot
            fixedState = spot.headerState
        }

        /// A card of a full row for an item that the main search found in a list. A row that answers the text shows its own
        /// detail, which says how the spot read the text (A3).
        public init(spot: Spot, item: SpotItem, isAnswer: Bool = false) {
            id = "\(spot.id)\n\(item.run)"
            sizeChoice = .strip
            gridChoice = nil
            letter = nil
            self.item = item
            self.isAnswer = isAnswer
            run = nil
            fixedSpot = spot
            fixedState = SpotState(title: item.title, subtitle: isAnswer ? item.subtitle ?? spot.name : item.path(in: spot))
        }

        @MainActor public var spot: Spot {
            run?.spot ?? fixedSpot
        }

        /// The size of its card: the person's choice, or else its header (F9). A card of a fault is never small, so that its
        /// words show.
        @MainActor public var size: SpotSize {
            let size = sizeChoice ?? spot.size
            return spot.fault != nil && size == .small ? .wide : size
        }

        /// The words of its last failed call, until a call ends well.
        @MainActor public var failure: String? {
            run?.failure
        }

        /// Whether the grid shows it: the person's choice, or else what the spot says.
        @MainActor public var isOnGrid: Bool {
            gridChoice ?? state.isOnGrid
        }

        @MainActor public var kind: SpotKind {
            item == nil ? spot.kind : .launch
        }

        @MainActor public var symbol: String {
            item?.symbol ?? spot.symbol
        }

        /// Whether the card draws the image, the file icon or the glyph that its header names, in place of a symbol.
        @MainActor public var showsHeaderPicture: Bool {
            item?.symbol == nil && (spot.icon != nil || spot.glyph != nil)
        }

        @MainActor public var state: SpotState {
            run?.state ?? fixedState
        }

        /// Whether its card is on. A view that reads only this hears of no other change of its state.
        @MainActor public var isOn: Bool {
            run?.isOn ?? (fixedState.on == true)
        }

        /// What the card shows: its own state, with the words of its running work over it.
        @MainActor public var shownState: SpotState {
            run?.shownState ?? fixedState
        }

        /// The running work that its glyph shows.
        @MainActor public var work: ScriptCall? {
            run?.work.first
        }

        /// Whether a press of the card stops its running work.
        @MainActor public var stopsOnPress: Bool {
            run?.cardWork != nil
        }

        /// Whether two entries are one card: the same spot or row, the same choices and the same run.
        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.id == rhs.id && lhs.item == rhs.item && lhs.sizeChoice == rhs.sizeChoice && lhs.gridChoice == rhs.gridChoice
                && lhs.run === rhs.run && lhs.fixedSpot == rhs.fixedSpot && lhs.fixedState == rhs.fixedState
        }
    }
}
