import SwiftUI

struct ReorderButtonsSheet: View {
    @ObservedObject var buttonOrderManager = ButtonOrderManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    ForEach(buttonOrderManager.buttonOrder) { buttonType in
                        HStack(spacing: 12) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(buttonType.color.opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: buttonType.icon)
                                    .font(.title3)
                                    .foregroundColor(buttonType.color)
                            }

                            // Name
                            Text(buttonType.localizedName)
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    }
                    .onMove { source, destination in
                        buttonOrderManager.moveButton(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle(L10n.reorderButtons)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        buttonOrderManager.resetToDefault()
                    } label: {
                        Text(L10n.resetToDefault)
                            .foregroundColor(AppTheme.pink)
                    }
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    ReorderButtonsSheet()
}
