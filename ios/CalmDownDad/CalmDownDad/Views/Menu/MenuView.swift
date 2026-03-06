import SwiftUI

struct MenuView: View {
    let baby: Baby
    @ObservedObject var languageManager = LanguageManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Baby Profile Card
                babyProfileCard

                // Menu Sections
                menuSection(title: L10n.data, items: [
                    MenuItem(systemIcon: "chart.bar.doc.horizontal.fill", title: L10n.dailyReport, subtitle: L10n.aiGeneratedReport),
                    MenuItem(systemIcon: "calendar", title: L10n.history, subtitle: L10n.viewAllRecords),
                    MenuItem(systemIcon: "square.and.arrow.up.fill", title: L10n.exportData, subtitle: L10n.exportAsCSVPDF)
                ])

                menuSection(title: L10n.aiFeatures, items: [
                    MenuItem(systemIcon: "sparkles", title: L10n.smartQA, subtitle: L10n.askAIQuestions),
                    MenuItem(systemIcon: "bell.badge.fill", title: L10n.smartReminder, subtitle: L10n.dataBasedReminder)
                ])

                menuSection(title: L10n.settings, items: [
                    MenuItem(systemIcon: "face.smiling", title: L10n.babyInfo, subtitle: L10n.editBabyProfile),
                    MenuItem(systemIcon: "person.3.fill", title: L10n.familyMembers, subtitle: L10n.manageFamilyMembers),
                    MenuItem(systemIcon: "gearshape.fill", title: L10n.appSettings, subtitle: L10n.notificationLanguageTheme),
                    MenuItem(systemIcon: "questionmark.circle.fill", title: L10n.helpFeedback, subtitle: L10n.faqContactUs)
                ])

                // Version info
                versionInfo
            }
            .padding()
        }
        .background(AppTheme.background)
    }

    // MARK: - Baby Profile Card

    private var babyProfileCard: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppTheme.pink.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 35))
                    .foregroundColor(AppTheme.pink)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(baby.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)

                Text(baby.ageChineseString)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                if let gender = baby.gender {
                    Text(gender == .male ? L10n.boy : L10n.girl)
                        .font(.caption2)
                        .foregroundColor(AppTheme.pink)
                }
            }

            Spacer()

            // Edit button
            Button {
                // TODO: Edit baby info
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.pink)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Menu Section

    private func menuSection(title: String, items: [MenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    NavigationLink {
                        destinationView(for: item)
                    } label: {
                        MenuItemRow(item: item)
                    }

                    if item.id != items.last?.id {
                        Divider()
                            .background(AppTheme.surfaceBackground)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func destinationView(for item: MenuItem) -> some View {
        if item.title == L10n.smartQA {
            AskView()
        } else if item.title == L10n.dailyReport {
            ReportsListView(baby: baby)
        } else if item.title == L10n.appSettings {
            SettingsView()
        } else {
            PlaceholderView(title: item.title)
        }
    }

    // MARK: - Version Info

    private var versionInfo: some View {
        VStack(spacing: 4) {
            Text(L10n.appName)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            Text("\(L10n.version) 1.0.0")
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
        }
        .padding(.top, 20)
    }
}

// MARK: - Menu Item

struct MenuItem: Identifiable {
    let id = UUID()
    let systemIcon: String
    let title: String
    let subtitle: String
}

struct MenuItemRow: View {
    let item: MenuItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemIcon)
                .font(.title2)
                .foregroundColor(AppTheme.pink)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
    }
}

// MARK: - Placeholder View

struct PlaceholderView: View {
    let title: String

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppTheme.textSecondary)

                Text(L10n.featureInDevelopment)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)

                Text(String(format: L10n.comingSoon.replacingOccurrences(of: "%@", with: "%@"), title))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MenuView(baby: Baby(
            id: "1",
            familyId: "f1",
            name: "小明",
            birthDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
            gender: .male
        ))
    }
}
