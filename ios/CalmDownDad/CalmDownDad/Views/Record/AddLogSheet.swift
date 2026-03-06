import SwiftUI

struct AddLogSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date = Date()
    @State private var amount: String = ""
    @State private var notes: String = ""

    private var title: String {
        viewModel.selectedLogType.chineseName
    }

    private var showsAmount: Bool {
        switch viewModel.selectedLogType {
        case .milkBreast, .milkFormula, .milkSolid:
            return true
        default:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(viewModel.selectedLogType.themeColor.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Text(viewModel.selectedLogType.cuteIcon)
                            .font(.system(size: 40))
                    }

                    // Time picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("时间")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        DatePicker("", selection: $startTime)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)

                    // Amount input (for feeding types)
                    if showsAmount {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("用量 (ml)")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)

                            HStack {
                                TextField("", text: $amount)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("ml")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)

                        // Quick amount buttons
                        HStack(spacing: 12) {
                            ForEach([60, 90, 120, 150, 180], id: \.self) { ml in
                                Button {
                                    amount = "\(ml)"
                                } label: {
                                    Text("\(ml)")
                                        .font(.subheadline)
                                        .foregroundColor(amount == "\(ml)" ? .white : AppTheme.pink)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(amount == "\(ml)" ? AppTheme.pink : AppTheme.cardBackground)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        TextField("添加备注...", text: $notes)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)

                    Spacer()

                    // Save button
                    Button {
                        saveLog()
                    } label: {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.pink)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func saveLog() {
        let parsedAmount = Double(amount)
        let unit: PhysiologyLogUnit? = showsAmount ? .ml : nil

        Task {
            await viewModel.createLog(
                type: viewModel.selectedLogType,
                startTime: startTime,
                endTime: nil,
                amount: parsedAmount,
                unit: unit,
                notes: notes.isEmpty ? nil : notes
            )
        }
    }
}

#Preview {
    AddLogSheet(viewModel: RecordViewModel(baby: Baby(
        id: "1",
        familyId: "f1",
        name: "宝宝",
        birthDate: Date()
    )))
}
