import SwiftUI

struct AdviceResultView: View {
    let advice: ParentingAdvice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with Risk Badge
                headerSection

                // Summary
                summarySection

                // Key Points
                if !advice.keyPoints.isEmpty {
                    keyPointsSection
                }

                // Action Items
                if !advice.actionItems.isEmpty {
                    actionItemsSection
                }

                // Sources & Citations
                if !advice.citations.isEmpty || !advice.sourcesUsed.isEmpty {
                    sourcesSection
                }

                // Degraded Mode Raw Sources
                if advice.isDegraded && !advice.rawSources.isEmpty {
                    rawSourcesSection
                }

                // Disclaimer
                disclaimerSection
            }
            .padding()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RiskBadge(level: advice.riskLevel)
                Spacer()
                confidenceBadge
            }

            Text(advice.question)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption)
            Text("\(advice.confidencePercentage)% confidence")
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)

            Text(advice.summary)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Key Points

    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Points")
                .font(.headline)

            ForEach(Array(advice.keyPoints.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 28, height: 28)

                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }

                    Text(point)
                        .font(.body)
                }
            }
        }
    }

    // MARK: - Action Items

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Actions")
                .font(.headline)

            ForEach(advice.actionItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text(item)
                        .font(.body)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources")
                .font(.headline)

            // Source Status
            if !advice.sourcesUsed.isEmpty {
                ForEach(advice.sourcesUsed) { source in
                    HStack(spacing: 8) {
                        Image(systemName: source.statusIcon)
                            .foregroundColor(statusColor(for: source.status))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.source)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(source.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Citations
            if !advice.citations.isEmpty {
                Divider()

                ForEach(advice.citations) { citation in
                    HStack(alignment: .top, spacing: 8) {
                        SourceBadge(sourceType: citation.sourceType)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(citation.reference)
                                .font(.caption)
                                .fontWeight(.medium)

                            if let detail = citation.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func statusColor(for status: SourceStatusCode) -> Color {
        switch status {
        case .ok: return .green
        case .degraded: return .orange
        case .fallback: return .yellow
        case .skipped: return .gray
        }
    }

    // MARK: - Raw Sources (Degraded Mode)

    private var rawSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Limited Mode - Raw Sources")
                    .font(.headline)
            }

            Text("AI synthesis was limited. Here are the raw source excerpts:")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(advice.rawSources, id: \.self) { source in
                Text(source)
                    .font(.caption)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)

            Text(advice.disclaimer)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    AdviceResultView(advice: ParentingAdvice(
        question: "Why is my baby sleeping less after vaccination?",
        summary: "Reduced sleep after vaccination is a common and typically temporary response. Your baby's immune system is working hard to build protection, which can cause mild discomfort and affect sleep patterns for 24-72 hours.",
        keyPoints: [
            "[Medical] Post-vaccine sleep disruption is normal and usually resolves within 48-72 hours",
            "[Data] Your baby's sleep reduced by 20% compared to the 7-day baseline",
            "[Social] Many parents report similar experiences, with most seeing improvement by day 3"
        ],
        actionItems: [
            "Offer extra comfort and cuddles",
            "Consider acetaminophen if your pediatrician recommends",
            "Monitor for fever above 101°F"
        ],
        riskLevel: .low,
        confidenceScore: 0.85,
        citations: [
            Citation(sourceType: "medical", reference: "AAP Immunization Guide, p.42", detail: nil),
            Citation(sourceType: "data_analysis", reference: "7-day trend analysis", detail: nil),
            Citation(sourceType: "xhs_post", reference: "XHS Consensus (8 posts)", detail: nil)
        ],
        sourcesUsed: [
            SourceStatus(source: "Medical Knowledge Base", status: .ok, message: "Retrieved relevant immunization guidance"),
            SourceStatus(source: "Data Analysis", status: .ok, message: "Analyzed 7 days of sleep data"),
            SourceStatus(source: "Social Insights", status: .ok, message: "Found 8 relevant community discussions")
        ]
    ))
}
