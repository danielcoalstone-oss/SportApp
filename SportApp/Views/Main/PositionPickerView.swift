import SwiftUI

struct PositionPickerView: View {
    @Binding var selectedPositions: [FootballPosition]
    var onSelectionChanged: (([FootballPosition]) -> Void)? = nil

    var body: some View {
        List {
            ForEach(FootballPositionGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(group.positions) { position in
                        Button {
                            toggle(position)
                        } label: {
                            HStack {
                                Text(position.rawValue)
                                Spacer()
                                if selectedPositions.contains(position) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Предпочитаемая позиция")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ position: FootballPosition) {
        if let index = selectedPositions.firstIndex(of: position) {
            selectedPositions.remove(at: index)
        } else {
            selectedPositions.append(position)
        }
        onSelectionChanged?(selectedPositions)
    }
}
