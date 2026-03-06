import SwiftUI

struct MenuView: View {
    let baby: Baby

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Baby Profile Card
                babyProfileCard

                // Menu Sections
                menuSection(title: "数据", items: [
                    MenuItem(icon: "📊", title: "每日报告", subtitle: "AI 生成的健康报告"),
                    MenuItem(icon: "📅", title: "历史记录", subtitle: "查看所有记录"),
                    MenuItem(icon: "📤", title: "导出数据", subtitle: "导出为 CSV 或 PDF")
                ])

                menuSection(title: "AI 功能", items: [
                    MenuItem(icon: "✨", title: "智能问答", subtitle: "向 AI 咨询育儿问题"),
                    MenuItem(icon: "🔔", title: "智能提醒", subtitle: "基于数据的喂养提醒")
                ])

                menuSection(title: "设置", items: [
                    MenuItem(icon: "👶", title: "宝宝信息", subtitle: "编辑宝宝资料"),
                    MenuItem(icon: "👨‍👩‍👧", title: "家庭成员", subtitle: "管理家庭成员"),
                    MenuItem(icon: "⚙️", title: "应用设置", subtitle: "通知、语言、主题"),
                    MenuItem(icon: "❓", title: "帮助与反馈", subtitle: "常见问题、联系我们")
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

                Text("👶")
                    .font(.system(size: 35))
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
                    Text(gender == .male ? "男孩" : "女孩")
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
        switch item.title {
        case "智能问答":
            AskView()
        case "每日报告":
            ReportsListView(baby: baby)
        default:
            PlaceholderView(title: item.title)
        }
    }

    // MARK: - Version Info

    private var versionInfo: some View {
        VStack(spacing: 4) {
            Text("NurtureMind")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            Text("版本 1.0.0")
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
        }
        .padding(.top, 20)
    }
}

// MARK: - Menu Item

struct MenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

struct MenuItemRow: View {
    let item: MenuItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.icon)
                .font(.title2)
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

                Text("功能开发中")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(title) 即将推出")
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
