import SwiftUI

struct AddEventView: View {
    @ObservedObject var viewModel: BabyDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ContextEventType = .vaccine
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()
    @State private var notes: String = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Type Selection
                Section("Event Type") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ContextEventType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                                // Set default title based on type
                                if title.isEmpty {
                                    title = defaultTitle(for: type)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.title2)
                                    Text(type.displayName)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedType == type ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedType == type ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // Title
                Section("Title") {
                    TextField("e.g., 2-Month Vaccinations", text: $title)
                }

                // Date Section
                Section("Date") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                    Toggle("Has End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                // Notes
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)

                    Text("Add any relevant details about this event")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Common Events Quick Add
                Section("Quick Add") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(quickAddOptions, id: \.title) { option in
                            Button {
                                selectedType = option.type
                                title = option.title
                            } label: {
                                HStack {
                                    Image(systemName: option.type.icon)
                                        .font(.caption)
                                    Text(option.title)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
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

    private func saveEvent() {
        let finalEndDate: Date? = hasEndDate ? endDate : nil

        Task {
            await viewModel.createEvent(
                type: selectedType,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                endDate: finalEndDate,
                notes: notes.isEmpty ? nil : notes
            )
        }
    }

    private func defaultTitle(for type: ContextEventType) -> String {
        switch type {
        case .vaccine: return ""
        case .travel: return ""
        case .jetLag: return "Jet Lag Adjustment"
        case .illness: return ""
        case .milestone: return ""
        case .other: return ""
        }
    }

    private var quickAddOptions: [(type: ContextEventType, title: String)] {
        [
            (.vaccine, "2-Month Vaccines"),
            (.vaccine, "4-Month Vaccines"),
            (.vaccine, "6-Month Vaccines"),
            (.milestone, "First Tooth"),
            (.milestone, "Rolling Over"),
            (.milestone, "Sitting Up"),
            (.illness, "Cold/Flu"),
            (.illness, "Fever"),
        ]
    }
}

#Preview {
    AddEventView(viewModel: BabyDetailViewModel(baby: Baby(
        id: "1",
        familyId: "f1",
        name: "Emma",
        birthDate: Date()
    )))
}
