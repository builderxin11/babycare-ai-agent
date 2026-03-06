import SwiftUI

struct AskView: View {
    @StateObject private var viewModel = AskViewModel()
    @FocusState private var isQuestionFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.advice != nil {
                    // Show result
                    adviceResultContent
                } else {
                    // Show ask form
                    askFormContent
                }
            }
        }
        .navigationTitle("AI 智能问答")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("错误", isPresented: .constant(viewModel.error != nil)) {
            Button("确定") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
        .task {
            await viewModel.loadBabies()
        }
    }

    // MARK: - Ask Form

    private var askFormContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerView

                // Baby Picker
                if !viewModel.babies.isEmpty {
                    babyPicker
                } else if viewModel.isLoadingBabies {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.pink))
                }

                // Question Input
                questionInput

                // Sample Questions
                sampleQuestionsSection

                // Submit Button
                submitButton
            }
            .padding()
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.pink)

            Text("智能育儿助手")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)

            Text("基于医学知识和社区经验的 AI 建议")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical)
    }

    private var babyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择宝宝")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            Menu {
                ForEach(viewModel.babies) { baby in
                    Button {
                        viewModel.selectedBaby = baby
                    } label: {
                        HStack {
                            Text(baby.name)
                            Text("(\(baby.ageChineseString))")
                            if viewModel.selectedBaby?.id == baby.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "face.smiling")
                        .foregroundColor(AppTheme.pink)

                    if let baby = viewModel.selectedBaby {
                        Text(baby.name)
                            .foregroundColor(AppTheme.textPrimary)
                        Text(baby.ageChineseString)
                            .foregroundColor(AppTheme.textSecondary)
                    } else {
                        Text("选择宝宝")
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }
        }
    }

    private var questionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("您的问题")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.question)
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .focused($isQuestionFocused)

                if viewModel.question.isEmpty {
                    Text("例如：宝宝打疫苗后食欲下降正常吗？")
                        .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var sampleQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常见问题")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(sampleQuestions, id: \.self) { question in
                    Button {
                        viewModel.question = question
                        isQuestionFocused = true
                    } label: {
                        Text(question)
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.pink.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var sampleQuestions: [String] {
        [
            "宝宝睡眠时间正常吗？",
            "打疫苗后需要注意什么？",
            "辅食添加时间表？",
            "宝宝哭闹怎么办？",
            "如何帮助宝宝睡整觉？"
        ]
    }

    private var submitButton: some View {
        Button {
            Task {
                isQuestionFocused = false
                await viewModel.askAgent()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "sparkles")
                }
                Text(viewModel.isLoading ? "AI 分析中..." : "获取 AI 建议")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canAsk ? AppTheme.pink : AppTheme.textSecondary)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canAsk || viewModel.isLoading)
    }

    // MARK: - Advice Result

    private var adviceResultContent: some View {
        VStack {
            ScrollView {
                AdviceResultViewDark(advice: viewModel.advice!)
            }

            Button {
                viewModel.clearAdvice()
            } label: {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("继续提问")
                }
                .font(.headline)
                .foregroundColor(AppTheme.pink)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }
            .padding()
        }
    }
}

// MARK: - Advice Result View (Dark Theme)

struct AdviceResultViewDark: View {
    let advice: ParentingAdvice

    var body: some View {
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

            // Sources
            if !advice.citations.isEmpty {
                sourcesSection
            }

            // Disclaimer
            disclaimerSection
        }
        .padding()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RiskBadgeDark(level: advice.riskLevel)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text("\(advice.confidencePercentage)% 置信度")
                        .font(.caption)
                }
                .foregroundColor(AppTheme.textSecondary)
            }

            Text(advice.question)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("摘要")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text(advice.summary)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("要点")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(Array(advice.keyPoints.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.pink.opacity(0.2))
                            .frame(width: 28, height: 28)

                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.pink)
                    }

                    Text(point)
                        .font(.body)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
    }

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建议措施")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(advice.actionItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.green)

                    Text(item)
                        .font(.body)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.green.opacity(0.1))
        .cornerRadius(12)
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("参考来源")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(advice.citations) { citation in
                HStack(alignment: .top, spacing: 8) {
                    SourceBadgeDark(sourceType: citation.sourceType)

                    Text(citation.reference)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(AppTheme.blue)

            Text(advice.disclaimer)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Risk Badge (Dark Theme)

struct RiskBadgeDark: View {
    let level: RiskLevel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)

            Text(level.chineseName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var iconName: String {
        switch level {
        case .low: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .high: return "xmark.shield.fill"
        }
    }

    private var badgeColor: Color {
        switch level {
        case .low: return AppTheme.green
        case .medium: return AppTheme.orange
        case .high: return Color.red
        }
    }
}

extension RiskLevel {
    var chineseName: String {
        switch self {
        case .low: return "低风险"
        case .medium: return "中风险"
        case .high: return "高风险"
        }
    }
}

// MARK: - Source Badge (Dark Theme)

struct SourceBadgeDark: View {
    let sourceType: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)

            Text(displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(6)
    }

    private var iconName: String {
        switch sourceType.lowercased() {
        case "data_analysis", "data": return "chart.bar.fill"
        case "medical", "book": return "book.fill"
        case "xhs_post", "social": return "bubble.left.and.bubble.right.fill"
        default: return "doc.fill"
        }
    }

    private var displayName: String {
        switch sourceType.lowercased() {
        case "data_analysis", "data": return "数据分析"
        case "medical", "book": return "医学知识"
        case "xhs_post", "social": return "社区经验"
        default: return sourceType
        }
    }

    private var badgeColor: Color {
        switch sourceType.lowercased() {
        case "data_analysis", "data": return AppTheme.blue
        case "medical", "book": return AppTheme.purple
        case "xhs_post", "social": return AppTheme.orange
        default: return AppTheme.textSecondary
        }
    }
}

#Preview {
    NavigationStack {
        AskView()
    }
}
