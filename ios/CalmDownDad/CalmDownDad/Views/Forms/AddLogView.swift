import SwiftUI

struct AddLogView: View {
    @ObservedObject var viewModel: BabyDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: PhysiologyLogType = .milkFormula
    @State private var startTime: Date = Date()
    @State private var hasEndTime: Bool = false
    @State private var endTime: Date = Date()
    @State private var amount: String = ""
    @State private var selectedUnit: PhysiologyLogUnit = .ml
    @State private var notes: String = ""

    private var canSave: Bool {
        // Basic validation - type is always set
        true
    }

    private var showsAmount: Bool {
        switch selectedType {
        case .milkBreast, .milkFormula, .milkSolid:
            return true
        case .sleep, .diaperWet, .diaperDirty, .bath:
            return false
        }
    }

    private var showsDuration: Bool {
        selectedType == .sleep || selectedType == .milkBreast
    }

    private var defaultUnit: PhysiologyLogUnit {
        switch selectedType {
        case .milkBreast, .milkFormula, .milkSolid:
            return .ml
        case .sleep:
            return .minutes
        case .diaperWet, .diaperDirty, .bath:
            return .count
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Type Selection
                Section("Type") {
                    ForEach(LogCategory.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ForEach(PhysiologyLogType.allCases.filter { $0.category == category }, id: \.self) { type in
                                    Button {
                                        selectedType = type
                                        selectedUnit = defaultUnit
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: type.icon)
                                                .font(.title3)
                                            Text(type.displayName)
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(selectedType == type ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedType == type ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }

                // Time Section
                Section("Time") {
                    DatePicker("Start", selection: $startTime)

                    if showsDuration {
                        Toggle("Add End Time", isOn: $hasEndTime)

                        if hasEndTime {
                            DatePicker("End", selection: $endTime, in: startTime...)
                        }
                    }
                }

                // Amount Section
                if showsAmount {
                    Section("Amount") {
                        HStack {
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)

                            Picker("Unit", selection: $selectedUnit) {
                                Text("ml").tag(PhysiologyLogUnit.ml)
                                Text("oz").tag(PhysiologyLogUnit.oz)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                    }
                }

                // Notes Section
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLog()
                    }
                    .disabled(!canSave || viewModel.isLoading)
                }
            }
            .disabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func saveLog() {
        let parsedAmount = Double(amount)
        let unit: PhysiologyLogUnit? = showsAmount ? selectedUnit : (showsDuration ? .minutes : nil)
        let finalEndTime: Date? = (showsDuration && hasEndTime) ? endTime : nil

        Task {
            await viewModel.createLog(
                type: selectedType,
                startTime: startTime,
                endTime: finalEndTime,
                amount: parsedAmount,
                unit: unit,
                notes: notes.isEmpty ? nil : notes
            )
        }
    }
}

#Preview {
    AddLogView(viewModel: BabyDetailViewModel(baby: Baby(
        id: "1",
        familyId: "f1",
        name: "Emma",
        birthDate: Date()
    )))
}
