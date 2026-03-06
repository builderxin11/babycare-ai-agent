# CalmDownDad iOS App

Native iOS app for CalmDownDad - 智能育儿助手

## Design

The app features a dark theme with pink accents, inspired by modern baby tracking apps:

- **Dark background** with card-based UI
- **Timeline view** with hour markers on the left
- **Cute emoji icons** for activities
- **Quick-add buttons** for fast logging
- **Chinese localization** support

## Screenshots

The app includes 4 main tabs:
1. **记录 (Record)** - Timeline view with daily logs
2. **摘要 (Summary)** - Weekly stats and trends
3. **成长曲线 (Growth)** - WHO-based growth charts
4. **菜单 (Menu)** - Settings and AI features

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

## Setup

### 1. Create Xcode Project

1. Open Xcode and create a new iOS App project:
   - Product Name: `CalmDownDad`
   - Team: Select your team
   - Organization Identifier: `com.calmdowndad`
   - Interface: SwiftUI
   - Language: Swift

2. Delete the default `ContentView.swift` and `CalmDownDadApp.swift` created by Xcode

3. Drag the contents of `ios/CalmDownDad/` folder into the Xcode project:
   - App/
   - Models/
   - Services/
   - ViewModels/
   - Views/
   - Resources/

### 2. Add Swift Package Dependencies

1. In Xcode, go to File → Add Package Dependencies
2. Enter URL: `https://github.com/aws-amplify/amplify-swift`
3. Select version: `2.0.0` or later
4. Add these products to your target:
   - `Amplify`
   - `AWSAPIPlugin`
   - `AWSCognitoAuthPlugin`

### 3. Configure Amplify

The `amplify_outputs.json` file is already copied to `Resources/`. Ensure it's added to your Xcode project and target.

### 4. Configure App Transport Security (Debug)

For local development with `localhost` API, add to `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

### 5. Update Configuration

Edit `Services/Configuration.swift` to set your API URLs:

```swift
#if DEBUG
static let agentAPIBaseURL = URL(string: "http://localhost:8000")!
#else
static let agentAPIBaseURL = URL(string: "https://your-production-api.com")!
#endif
```

## Project Structure

```
CalmDownDad/
├── App/
│   ├── CalmDownDadApp.swift      # Entry point
│   ├── ContentView.swift         # Main tab view
│   └── Theme.swift               # Colors & styling
├── Models/
│   ├── Baby.swift
│   ├── PhysiologyLog.swift
│   ├── ContextEvent.swift
│   ├── ParentingAdvice.swift
│   ├── DailyReport.swift
│   └── Enums.swift
├── Services/
│   ├── AmplifyService.swift      # DynamoDB via Amplify
│   ├── AgentAPIService.swift     # FastAPI /ask, /report
│   └── Configuration.swift       # API URLs, JSON config
├── ViewModels/
│   ├── BabyListViewModel.swift
│   ├── RecordViewModel.swift
│   ├── AskViewModel.swift
│   └── ReportsViewModel.swift
├── Views/
│   ├── Record/                   # Main timeline view
│   │   ├── RecordView.swift
│   │   └── AddLogSheet.swift
│   ├── Summary/                  # Weekly stats
│   │   └── SummaryView.swift
│   ├── GrowthChart/              # Growth tracking
│   │   └── GrowthChartView.swift
│   ├── Menu/                     # Settings & AI
│   │   └── MenuView.swift
│   ├── Ask/                      # AI assistant
│   │   └── AskView.swift
│   ├── Reports/                  # Daily reports
│   │   ├── ReportsListView.swift
│   │   └── ReportDetailView.swift
│   └── Components/               # Reusable UI
└── Resources/
    └── amplify_outputs.json
```

## Features

### Tab 1: 记录 (Record)
- **Timeline view** with 24-hour markers
- **Daily summary** bar (feeding, sleep, diaper counts)
- **Activity dots** on hour markers showing logged events
- **Quick-add buttons** for common activities:
  - 配方奶 (Formula)
  - 睡觉 (Sleep)
  - 起床 (Wake up)
  - 便便 (Diaper)
  - 断奶食品 (Solid food)
  - 瓶喂母乳 (Breast milk)
- **Floating buttons** for search and timer

### Tab 2: 摘要 (Summary)
- Weekly statistics cards
- Trend indicators (improving/stable/declining)
- AI insights quick access

### Tab 3: 成长曲线 (Growth)
- Weight, height, head circumference tracking
- WHO standard percentile charts
- Measurement history

### Tab 4: 菜单 (Menu)
- Baby profile management
- Daily AI reports
- History & data export
- Settings & help

### AI Features
- **智能问答**: Ask parenting questions
- **每日报告**: AI-generated health reports
- **Source attribution**: Medical, data, and social sources

## Theme Colors

```swift
AppTheme.background    // #0D0D0D (dark)
AppTheme.cardBackground // #1A1A1A
AppTheme.pink          // #E91E8C (accent)
AppTheme.feedingColor  // #FFD93D (yellow)
AppTheme.sleepColor    // #9B7EDE (purple)
AppTheme.diaperColor   // #FF8C42 (orange)
AppTheme.solidFoodColor // #6BCB77 (green)
```

## Running the App

1. Ensure the FastAPI backend is running at `http://localhost:8000`
2. Run `npx ampx sandbox` in the project root to start Amplify sandbox
3. Build and run in Xcode Simulator or device

## Verification Checklist

- [ ] Build and run on iOS Simulator
- [ ] Onboarding: Add first baby
- [ ] Record tab: Add feeding/sleep logs via quick buttons
- [ ] Summary tab: View weekly stats
- [ ] Menu > AI 智能问答: Ask a question
- [ ] Menu > 每日报告: Generate report

## Troubleshooting

### Amplify Configuration Error
- Ensure `amplify_outputs.json` is in the app bundle
- Check that the file is added to the target

### Network Errors
- For localhost testing, ensure `NSAllowsLocalNetworking` is enabled
- Verify the FastAPI server is running

### Dark Theme Issues
- Ensure `.preferredColorScheme(.dark)` is set on ContentView
