import SwiftUI

struct SettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Language Section
                    languageSection

                    // App Info
                    appInfoSection
                }
                .padding()
            }
        }
        .navigationTitle(L10n.appSettings)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Language Section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.language)
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        withAnimation {
                            languageManager.setLanguage(language)
                        }
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.pink)
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                    }

                    if language != AppLanguage.allCases.last {
                        Divider()
                            .background(AppTheme.surfaceBackground)
                    }
                }
            }
            .cornerRadius(12)
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(spacing: 8) {
            Text(L10n.appName)
                .font(.headline)
                .foregroundColor(AppTheme.pink)

            Text("\(L10n.version) 1.0.0")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.top, 20)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
