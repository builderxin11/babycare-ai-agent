import SwiftUI

struct ContentView: View {
    @EnvironmentObject var amplifyService: AmplifyService
    @StateObject private var babyListVM = BabyListViewModel()
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if amplifyService.configurationError != nil {
                configurationErrorView
            } else if babyListVM.babies.isEmpty && !babyListVM.isLoading {
                // No babies - show onboarding
                onboardingView
            } else if let baby = babyListVM.babies.first {
                // Main app with baby selected
                mainAppView(baby: baby)
            } else {
                // Loading state
                loadingView
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await babyListVM.loadBabies()
        }
    }

    // MARK: - Main App View

    private func mainAppView(baby: Baby) -> some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Content based on selected tab
                switch selectedTab {
                case 0:
                    RecordView(baby: baby)
                case 1:
                    SummaryView(baby: baby)
                case 2:
                    GrowthChartView(baby: baby)
                case 3:
                    MenuView(baby: baby)
                default:
                    RecordView(baby: baby)
                }

                // Bottom tab bar
                customTabBar
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack {
            TabBarButton(
                icon: "pencil",
                title: "记录",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }

            TabBarButton(
                icon: "chart.bar",
                title: "摘要",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }

            TabBarButton(
                icon: "chart.line.uptrend.xyaxis",
                title: "成长曲线",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }

            TabBarButton(
                icon: "line.3.horizontal",
                title: "菜单",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(AppTheme.cardBackground)
    }

    // MARK: - Onboarding View

    private var onboardingView: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text("👶")
                    .font(.system(size: 80))

                Text("CalmDownDad")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.pink)

                Text("智能育儿助手")
                    .font(.title3)
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Button {
                    babyListVM.showingAddBaby = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加宝宝")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.pink)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .sheet(isPresented: $babyListVM.showingAddBaby) {
            AddBabySheetDark(viewModel: babyListVM)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.pink))
                    .scaleEffect(1.5)

                Text("加载中...")
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Configuration Error View

    private var configurationErrorView: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppTheme.orange)

                Text("配置错误")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)

                Text(amplifyService.configurationError?.localizedDescription ?? "Unknown error")
                    .font(.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    Task {
                        await amplifyService.configure()
                    }
                } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                        .foregroundColor(AppTheme.pink)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))

                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? AppTheme.pink : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Add Baby Sheet (Dark Theme)

struct AddBabySheetDark: View {
    @ObservedObject var viewModel: BabyListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: BabyGender?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(AppTheme.pink.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Text("👶")
                            .font(.system(size: 50))
                    }

                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("宝宝昵称")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        TextField("", text: $name)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                    }

                    // Birth date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("出生日期")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                    }

                    // Gender selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("性别")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        HStack(spacing: 12) {
                            GenderButton(
                                icon: "👦",
                                title: "男孩",
                                isSelected: gender == .male
                            ) {
                                gender = .male
                            }

                            GenderButton(
                                icon: "👧",
                                title: "女孩",
                                isSelected: gender == .female
                            ) {
                                gender = .female
                            }
                        }
                    }

                    Spacer()

                    // Save button
                    Button {
                        Task {
                            await viewModel.createBaby(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                birthDate: birthDate,
                                gender: gender,
                                notes: nil
                            )
                        }
                    } label: {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSave ? AppTheme.pink : AppTheme.textSecondary)
                            .cornerRadius(12)
                    }
                    .disabled(!canSave || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("添加宝宝")
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
}

struct GenderButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.title)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? AppTheme.pink : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? AppTheme.pink.opacity(0.2) : AppTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.pink : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AmplifyService.shared)
}
