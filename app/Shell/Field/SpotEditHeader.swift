import OpenspotCore
import SwiftUI

struct SpotEditHeader: View {
    let model: SpotsModel

    var body: some View {
        let rect = SpotFieldView.rect
        HStack {
            Text(model.isArranging ? "Arranging spots" : "Edit Spots")
                .font(SpotType.input)
                .foregroundStyle(SpotTheme.ink)
            Spacer()
            Picker("Columns", selection: Binding(get: { model.grid.columns }, set: { model.set(columns: $0) })) {
                ForEach(OpenspotCore.GridLayout.widths, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            SpotRoundButton(icon: .symbol("checkmark"), label: "Done", look: .strong) { model.endEditing() }
        }
        .padding(.leading, SpotTokens.padding + SpotTokens.glyphInset)
        .padding(.trailing, SpotTokens.padding)
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
    }
}
