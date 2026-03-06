import SwiftUI

struct AddBabySheet: View {
    @ObservedObject var viewModel: BabyListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: BabyGender?
    @State private var notes: String = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)

                    DatePicker(
                        "Birth Date",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                Section {
                    Picker("Gender", selection: $gender) {
                        Text("Not Specified").tag(BabyGender?.none)
                        ForEach(BabyGender.allCases, id: \.self) { gender in
                            Text(gender.displayName).tag(BabyGender?.some(gender))
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Baby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.createBaby(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                birthDate: birthDate,
                                gender: gender,
                                notes: notes.isEmpty ? nil : notes
                            )
                        }
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
}

#Preview {
    AddBabySheet(viewModel: BabyListViewModel())
}
