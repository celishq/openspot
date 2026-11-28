import Foundation

extension SpotsModel {
    public func take(_ act: PanelAct) -> Bool {
        asOnePress {
            switch act {
            case .open:
                showPanel()
                return true
            case .close:
                if isShown { host.dismiss() }
                return true
            case .type(let text):
                search(text)
                return true
            case .key(let key):
                return handleKey(key) || handleSearchKey(key)
            case .press(let id):
                guard let part = openParts?.parts.first(where: { $0.id == id }) else { return false }
                pressPart(part)
                return true
            }
        }
    }

    public var panelState: PanelState {
        PanelState(values: [
            "open": String(isShown),
            "text": searchText,
            "sheet": openSheetID ?? "",
            "route": flow.current?.route ?? "",
            "selected": openSheetID == nil ? selectedEntry?.id ?? "" : openItems?.selectedItem?.run ?? "",
            "menu": String(isMenuOpen),
            "chips": String(attachments.chips.count),
            "moving": String(transition.isMoving)
        ])
    }
}
