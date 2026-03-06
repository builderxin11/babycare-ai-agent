import SwiftUI

struct ReportsListView: View {
    @StateObject private var viewModel: ReportsViewModel

    init(baby: Baby) {
        _viewModel = StateObject(wrappedValue: ReportsViewModel(baby: baby))
    }

    var body: some View {
        VStack {
            if viewModel.selectedReport != nil {
                // Show report detail
                reportDetailContent
            } else {
                // Show reports list
                reportsListContent
            }
        }
        .navigationTitle("Daily Reports")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }

    // MARK: - Reports List

    private var reportsListContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Generate Report Button
                generateReportButton

                // Reports List
                if viewModel.reports.isEmpty {
                    emptyStateView
                } else {
                    reportsGrid
                }
            }
            .padding()
        }
    }

    private var generateReportButton: some View {
        Button {
            Task {
                await viewModel.generateReport()
            }
        } label: {
            HStack {
                if viewModel.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "doc.badge.plus")
                }
                Text(viewModel.isGenerating ? "Generating Report..." : "Generate Today's Report")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isGenerating)
    }

    private var reportsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Reports")
                .font(.headline)

            ForEach(viewModel.sortedReports) { report in
                ReportCardView(report: report) {
                    viewModel.selectReport(report)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Reports Yet")
                .font(.headline)

            Text("Generate your first daily health report to get AI-powered insights about your baby's patterns.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Report Detail

    private var reportDetailContent: some View {
        VStack {
            ReportDetailView(report: viewModel.selectedReport!)

            Button {
                viewModel.clearSelection()
            } label: {
                Label("Back to Reports", systemImage: "arrow.left")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
}

// MARK: - Report Card View

struct ReportCardView: View {
    let report: DailyReport
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.reportDateDisplayString)
                            .font(.headline)

                        Text(report.babyName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    healthStatusBadge
                }

                // Summary Preview
                Text(report.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Trend Indicator
                HStack {
                    trendBadge

                    Spacer()

                    if report.hasWarnings {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(report.warnings.count) warning\(report.warnings.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var healthStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: report.healthStatus.icon)
            Text(report.healthStatus.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch report.healthStatus {
        case .healthy: return .green
        case .monitor: return .orange
        case .concern: return .red
        }
    }

    private var trendBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: report.trendDirection.icon)
            Text(report.trendDirection.displayName)
                .font(.caption)
        }
        .foregroundColor(trendColor)
    }

    private var trendColor: Color {
        switch report.trendDirection {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        ReportsListView(baby: Baby(
            id: "1",
            familyId: "f1",
            name: "Emma",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        ))
    }
}
