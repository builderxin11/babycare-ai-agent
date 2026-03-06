import SwiftUI

struct BabyListView: View {
    @StateObject private var viewModel = BabyListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.babies.isEmpty {
                    LoadingView(message: "Loading babies...")
                } else if viewModel.babies.isEmpty {
                    emptyStateView
                } else {
                    babyListContent
                }
            }
            .navigationTitle("My Babies")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingAddBaby = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddBaby) {
                AddBabySheet(viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
            .refreshable {
                await viewModel.loadBabies()
            }
        }
        .task {
            await viewModel.loadBabies()
        }
    }

    private var babyListContent: some View {
        List {
            ForEach(viewModel.babies) { baby in
                NavigationLink(value: baby) {
                    BabyRowView(baby: baby)
                }
            }
            .onDelete(perform: deleteBabies)
        }
        .navigationDestination(for: Baby.self) { baby in
            BabyDetailView(baby: baby)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.and.child.holdinghands")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Babies Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add your first baby to start tracking their health and get personalized advice.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                viewModel.showingAddBaby = true
            } label: {
                Label("Add Baby", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func deleteBabies(at offsets: IndexSet) {
        Task {
            for index in offsets {
                await viewModel.deleteBaby(viewModel.babies[index])
            }
        }
    }
}

#Preview {
    BabyListView()
}
