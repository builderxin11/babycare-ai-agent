import SwiftUI

struct BabyDetailView: View {
    @StateObject private var viewModel: BabyDetailViewModel

    init(baby: Baby) {
        _viewModel = StateObject(wrappedValue: BabyDetailViewModel(baby: baby))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Baby Info Header
                babyInfoHeader

                // Action Buttons
                actionButtons

                // Recent Logs Section
                if !viewModel.physiologyLogs.isEmpty {
                    logsSection
                }

                // Recent Events Section
                if !viewModel.contextEvents.isEmpty {
                    eventsSection
                }

                // Empty State
                if viewModel.physiologyLogs.isEmpty && viewModel.contextEvents.isEmpty && !viewModel.isLoading {
                    emptyDataView
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.baby.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading {
                LoadingView(message: "Loading...")
            }
        }
        .sheet(isPresented: $viewModel.showingAddLog) {
            AddLogView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingAddEvent) {
            AddEventView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Baby Info Header

    private var babyInfoHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))

                Text(viewModel.baby.name.prefix(1).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(avatarColor)
            }
            .frame(width: 80, height: 80)

            // Info
            VStack(spacing: 4) {
                Text(viewModel.baby.ageDisplayString + " old")
                    .font(.headline)

                if let gender = viewModel.baby.gender {
                    Text(gender.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Born \(viewModel.baby.birthDate.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let notes = viewModel.baby.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var avatarColor: Color {
        switch viewModel.baby.gender {
        case .male: return .blue
        case .female: return .pink
        case .other, .none: return .purple
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.showingAddLog = true
            } label: {
                Label("Add Log", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.showingAddEvent = true
            } label: {
                Label("Add Event", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            NavigationLink {
                ReportsListView(baby: viewModel.baby)
            } label: {
                Label("Reports", systemImage: "doc.text.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Logs Section

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Logs")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.physiologyLogs.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(viewModel.groupedLogs.prefix(3), id: \.date) { group in
                LogDayView(date: group.date, logs: group.logs)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Events")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.contextEvents.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(viewModel.recentEvents) { event in
                EventRowView(event: event)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Empty State

    private var emptyDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Data Yet")
                .font(.headline)

            Text("Start logging your baby's activities to track patterns and get personalized insights.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

#Preview {
    NavigationStack {
        BabyDetailView(baby: Baby(
            id: "1",
            familyId: "f1",
            name: "Emma",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .female,
            notes: "Our little sunshine"
        ))
    }
}
