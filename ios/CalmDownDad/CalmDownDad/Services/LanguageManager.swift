import Foundation
import SwiftUI
import Combine

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    var appName: String {
        switch self {
        case .chinese: return "爸妈别慌"
        case .english: return "Calm Down Dad"
        }
    }
}

// MARK: - Language Manager

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            // Default based on system language
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = systemLang.starts(with: "zh") ? .chinese : .english
        }
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}

// MARK: - Localization Keys

enum L10n {
    // MARK: - App
    static var appName: String { LanguageManager.shared.currentLanguage.appName }
    static var smartParentingAssistant: String { loc("smart_parenting_assistant") }

    // MARK: - Common
    static var save: String { loc("save") }
    static var cancel: String { loc("cancel") }
    static var delete: String { loc("delete") }
    static var edit: String { loc("edit") }
    static var add: String { loc("add") }
    static var loading: String { loc("loading") }
    static var retry: String { loc("retry") }
    static var time: String { loc("time") }
    static var notes: String { loc("notes") }
    static var addNotes: String { loc("add_notes") }
    static var today: String { loc("today") }
    static var saveChanges: String { loc("save_changes") }
    static var deleteRecord: String { loc("delete_record") }
    static var editRecord: String { loc("edit_record") }

    // MARK: - Tab Bar
    static var tabRecord: String { loc("tab_record") }
    static var tabSummary: String { loc("tab_summary") }
    static var tabGrowthChart: String { loc("tab_growth_chart") }
    static var tabMenu: String { loc("tab_menu") }

    // MARK: - Baby
    static var addBaby: String { loc("add_baby") }
    static var babyNickname: String { loc("baby_nickname") }
    static var birthDate: String { loc("birth_date") }
    static var gender: String { loc("gender") }
    static var boy: String { loc("boy") }
    static var girl: String { loc("girl") }

    // MARK: - Record Types
    static var formulaMilk: String { loc("formula_milk") }
    static var breastMilk: String { loc("breast_milk") }
    static var solidFood: String { loc("solid_food") }
    static var sleep: String { loc("sleep") }
    static var wakeUp: String { loc("wake_up") }
    static var diaper: String { loc("diaper") }
    static var dirtyDiaper: String { loc("dirty_diaper") }
    static var wetDiaper: String { loc("wet_diaper") }
    static var bath: String { loc("bath") }
    static var vaccine: String { loc("vaccine") }

    // MARK: - Record View
    static var parentingDiary: String { loc("parenting_diary") }
    static var custom: String { loc("custom") }
    static var amount: String { loc("amount") }
    static var sleeping: String { loc("sleeping") }
    static var invalid: String { loc("invalid") }

    // MARK: - Wake Up
    static var wakeUpTime: String { loc("wake_up_time") }
    static var correspondingSleep: String { loc("corresponding_sleep") }
    static var noActiveSleep: String { loc("no_active_sleep") }
    static var sleepDuration: String { loc("sleep_duration") }

    // MARK: - Vaccine
    static var vaccineRecord: String { loc("vaccine_record") }
    static var vaccineName: String { loc("vaccine_name") }
    static var enterVaccineName: String { loc("enter_vaccine_name") }
    static var commonVaccines: String { loc("common_vaccines") }
    static var vaccinationDate: String { loc("vaccination_date") }

    // MARK: - Growth Chart
    static var growthChart: String { loc("growth_chart") }
    static var basedOnWHO: String { loc("based_on_who") }
    static var weight: String { loc("weight") }
    static var height: String { loc("height") }
    static var headCircumference: String { loc("head_circumference") }
    static var latestMeasurement: String { loc("latest_measurement") }
    static var measurementRecords: String { loc("measurement_records") }
    static var referenceRange: String { loc("reference_range") }
    static var ageStandard: String { loc("age_standard") }
    static var currentPercentile: String { loc("current_percentile") }
    static var toMeasure: String { loc("to_measure") }
    static var measurementDate: String { loc("measurement_date") }
    static var addMeasurementRecord: String { loc("add_measurement_record") }
    static var needMoreData: String { loc("need_more_data") }
    static var weightChange: String { loc("weight_change") }
    static var heightChange: String { loc("height_change") }
    static var headCircumferenceChange: String { loc("head_circumference_change") }

    // MARK: - Summary
    static var weeklySummary: String { loc("weekly_summary") }
    static var weeklyStats: String { loc("weekly_stats") }
    static var feeding: String { loc("feeding") }
    static var diaperChange: String { loc("diaper_change") }
    static var weeklyTotal: String { loc("weekly_total") }
    static var dailyAverage: String { loc("daily_average") }
    static var trends: String { loc("trends") }
    static var feedingAmount: String { loc("feeding_amount") }
    static var sleepDurationTitle: String { loc("sleep_duration_title") }
    static var aiAnalysis: String { loc("ai_analysis") }
    static var getPersonalizedAdvice: String { loc("get_personalized_advice") }
    static var sameAsLastWeek: String { loc("same_as_last_week") }
    static var increased: String { loc("increased") }

    // MARK: - Menu
    static var data: String { loc("data") }
    static var dailyReport: String { loc("daily_report") }
    static var aiGeneratedReport: String { loc("ai_generated_report") }
    static var history: String { loc("history") }
    static var viewAllRecords: String { loc("view_all_records") }
    static var exportData: String { loc("export_data") }
    static var exportAsCSVPDF: String { loc("export_as_csv_pdf") }
    static var aiFeatures: String { loc("ai_features") }
    static var smartQA: String { loc("smart_qa") }
    static var askAIQuestions: String { loc("ask_ai_questions") }
    static var smartReminder: String { loc("smart_reminder") }
    static var dataBasedReminder: String { loc("data_based_reminder") }
    static var settings: String { loc("settings") }
    static var babyInfo: String { loc("baby_info") }
    static var editBabyProfile: String { loc("edit_baby_profile") }
    static var familyMembers: String { loc("family_members") }
    static var manageFamilyMembers: String { loc("manage_family_members") }
    static var appSettings: String { loc("app_settings") }
    static var notificationLanguageTheme: String { loc("notification_language_theme") }
    static var helpFeedback: String { loc("help_feedback") }
    static var faqContactUs: String { loc("faq_contact_us") }
    static var version: String { loc("version") }
    static var featureInDevelopment: String { loc("feature_in_development") }
    static var comingSoon: String { loc("coming_soon") }

    // MARK: - Settings
    static var language: String { loc("language") }
    static var selectLanguage: String { loc("select_language") }

    // MARK: - Custom Button
    static var customButton: String { loc("custom_button") }
    static var name: String { loc("name") }
    static var enterName: String { loc("enter_name") }
    static var icon: String { loc("icon") }
    static var color: String { loc("color") }

    // MARK: - Reorder Buttons
    static var reorderButtons: String { loc("reorder_buttons") }
    static var resetToDefault: String { loc("reset_to_default") }
    static var done: String { loc("done") }

    // MARK: - Errors
    static var configurationError: String { loc("configuration_error") }

    // MARK: - Time
    static var minutesAgo: String { loc("minutes_ago") }
    static var hoursAgo: String { loc("hours_ago") }
    static var hoursMinutesAgo: String { loc("hours_minutes_ago") }
    static var hours: String { loc("hours") }
    static var minutes: String { loc("minutes") }
    static var times: String { loc("times") }
    static var sleptFor: String { loc("slept_for") }

    // MARK: - Age
    static var years: String { loc("years") }
    static var months: String { loc("months") }
    static var days: String { loc("days") }

    // MARK: - Vaccine Names (Chinese)
    static var hepatitisB: String { loc("hepatitis_b") }
    static var bcg: String { loc("bcg") }
    static var polio: String { loc("polio") }
    static var dpt: String { loc("dpt") }
    static var mmr: String { loc("mmr") }
    static var japaneseEncephalitis: String { loc("japanese_encephalitis") }
    static var meningococcalA: String { loc("meningococcal_a") }
    static var hepatitisA: String { loc("hepatitis_a") }

    // MARK: - Helper
    private static func loc(_ key: String) -> String {
        return localizedStrings[LanguageManager.shared.currentLanguage]?[key] ?? key
    }

    // MARK: - Localized Strings Dictionary
    private static let localizedStrings: [AppLanguage: [String: String]] = [
        .chinese: chineseStrings,
        .english: englishStrings
    ]

    private static let chineseStrings: [String: String] = [
        // App
        "smart_parenting_assistant": "智能育儿助手",

        // Common
        "save": "保存",
        "cancel": "取消",
        "delete": "删除",
        "edit": "编辑",
        "add": "添加",
        "loading": "加载中...",
        "retry": "重试",
        "time": "时间",
        "notes": "备注",
        "add_notes": "添加备注...",
        "today": "今天",
        "save_changes": "保存修改",
        "delete_record": "删除此记录",
        "edit_record": "编辑记录",

        // Tab Bar
        "tab_record": "记录",
        "tab_summary": "摘要",
        "tab_growth_chart": "成长曲线",
        "tab_menu": "菜单",

        // Baby
        "add_baby": "添加宝宝",
        "baby_nickname": "宝宝昵称",
        "birth_date": "出生日期",
        "gender": "性别",
        "boy": "男孩",
        "girl": "女孩",

        // Record Types
        "formula_milk": "配方奶",
        "breast_milk": "母乳",
        "solid_food": "辅食",
        "sleep": "睡觉",
        "wake_up": "起床",
        "diaper": "尿布",
        "dirty_diaper": "便便",
        "wet_diaper": "小便",
        "bath": "洗澡",
        "vaccine": "疫苗",

        // Record View
        "parenting_diary": "育儿日记",
        "custom": "自定义",
        "amount": "用量",
        "sleeping": "睡眠中...",
        "invalid": "(无效)",

        // Wake Up
        "wake_up_time": "起床时间",
        "corresponding_sleep": "对应的睡眠记录",
        "no_active_sleep": "没有进行中的睡眠记录",
        "sleep_duration": "睡眠时长",

        // Vaccine
        "vaccine_record": "疫苗记录",
        "vaccine_name": "疫苗名称",
        "enter_vaccine_name": "输入疫苗名称",
        "common_vaccines": "常见疫苗",
        "vaccination_date": "接种日期",

        // Growth Chart
        "growth_chart": "成长曲线",
        "based_on_who": "基于WHO标准",
        "weight": "体重",
        "height": "身高",
        "head_circumference": "头围",
        "latest_measurement": "最新测量",
        "measurement_records": "测量记录",
        "reference_range": "参考范围",
        "age_standard": "同龄标准",
        "current_percentile": "当前百分位",
        "to_measure": "待测量",
        "measurement_date": "测量日期",
        "add_measurement_record": "添加%@记录",
        "need_more_data": "添加至少2条测量数据以查看成长曲线",
        "weight_change": "体重变化 (kg)",
        "height_change": "身高变化 (cm)",
        "head_circumference_change": "头围变化 (cm)",

        // Summary
        "weekly_summary": "本周摘要",
        "weekly_stats": "本周统计",
        "feeding": "喂养",
        "diaper_change": "换尿布",
        "weekly_total": "本周总计",
        "daily_average": "日均",
        "trends": "趋势",
        "feeding_amount": "喂养量",
        "sleep_duration_title": "睡眠时长",
        "ai_analysis": "AI 智能分析",
        "get_personalized_advice": "获取个性化育儿建议",
        "same_as_last_week": "与上周持平",
        "increased": "增加%@分钟",

        // Menu
        "data": "数据",
        "daily_report": "每日报告",
        "ai_generated_report": "AI 生成的健康报告",
        "history": "历史记录",
        "view_all_records": "查看所有记录",
        "export_data": "导出数据",
        "export_as_csv_pdf": "导出为 CSV 或 PDF",
        "ai_features": "AI 功能",
        "smart_qa": "智能问答",
        "ask_ai_questions": "向 AI 咨询育儿问题",
        "smart_reminder": "智能提醒",
        "data_based_reminder": "基于数据的喂养提醒",
        "settings": "设置",
        "baby_info": "宝宝信息",
        "edit_baby_profile": "编辑宝宝资料",
        "family_members": "家庭成员",
        "manage_family_members": "管理家庭成员",
        "app_settings": "应用设置",
        "notification_language_theme": "通知、语言、主题",
        "help_feedback": "帮助与反馈",
        "faq_contact_us": "常见问题、联系我们",
        "version": "版本",
        "feature_in_development": "功能开发中",
        "coming_soon": "%@ 即将推出",

        // Settings
        "language": "语言",
        "select_language": "选择语言",

        // Custom Button
        "custom_button": "自定义按钮",
        "name": "名称",
        "enter_name": "输入名称",
        "icon": "图标",
        "color": "颜色",

        // Reorder Buttons
        "reorder_buttons": "调整按钮顺序",
        "reset_to_default": "恢复默认顺序",
        "done": "完成",

        // Errors
        "configuration_error": "配置错误",

        // Time
        "minutes_ago": "%d分钟前",
        "hours_ago": "%d小时前",
        "hours_minutes_ago": "%d小时%d分钟前",
        "hours": "小时",
        "minutes": "分钟",
        "times": "次",
        "slept_for": "睡了%@",

        // Age
        "years": "岁",
        "months": "个月",
        "days": "天",

        // Vaccine Names
        "hepatitis_b": "乙肝疫苗",
        "bcg": "卡介苗",
        "polio": "脊灰疫苗",
        "dpt": "百白破疫苗",
        "mmr": "麻腮风疫苗",
        "japanese_encephalitis": "乙脑疫苗",
        "meningococcal_a": "A群流脑疫苗",
        "hepatitis_a": "甲肝疫苗",
    ]

    private static let englishStrings: [String: String] = [
        // App
        "smart_parenting_assistant": "Smart Parenting Assistant",

        // Common
        "save": "Save",
        "cancel": "Cancel",
        "delete": "Delete",
        "edit": "Edit",
        "add": "Add",
        "loading": "Loading...",
        "retry": "Retry",
        "time": "Time",
        "notes": "Notes",
        "add_notes": "Add notes...",
        "today": "Today",
        "save_changes": "Save Changes",
        "delete_record": "Delete this record",
        "edit_record": "Edit Record",

        // Tab Bar
        "tab_record": "Record",
        "tab_summary": "Summary",
        "tab_growth_chart": "Growth",
        "tab_menu": "Menu",

        // Baby
        "add_baby": "Add Baby",
        "baby_nickname": "Baby's Nickname",
        "birth_date": "Birth Date",
        "gender": "Gender",
        "boy": "Boy",
        "girl": "Girl",

        // Record Types
        "formula_milk": "Formula",
        "breast_milk": "Breast Milk",
        "solid_food": "Solid Food",
        "sleep": "Sleep",
        "wake_up": "Wake Up",
        "diaper": "Diaper",
        "dirty_diaper": "Dirty Diaper",
        "wet_diaper": "Wet Diaper",
        "bath": "Bath",
        "vaccine": "Vaccine",

        // Record View
        "parenting_diary": "Parenting Diary",
        "custom": "Custom",
        "amount": "Amount",
        "sleeping": "Sleeping...",
        "invalid": "(Invalid)",

        // Wake Up
        "wake_up_time": "Wake Up Time",
        "corresponding_sleep": "Corresponding Sleep",
        "no_active_sleep": "No active sleep record",
        "sleep_duration": "Sleep Duration",

        // Vaccine
        "vaccine_record": "Vaccine Record",
        "vaccine_name": "Vaccine Name",
        "enter_vaccine_name": "Enter vaccine name",
        "common_vaccines": "Common Vaccines",
        "vaccination_date": "Vaccination Date",

        // Growth Chart
        "growth_chart": "Growth Chart",
        "based_on_who": "Based on WHO Standards",
        "weight": "Weight",
        "height": "Height",
        "head_circumference": "Head Circ.",
        "latest_measurement": "Latest",
        "measurement_records": "Records",
        "reference_range": "Reference",
        "age_standard": "Age Standard",
        "current_percentile": "Percentile",
        "to_measure": "To Measure",
        "measurement_date": "Date",
        "add_measurement_record": "Add %@ Record",
        "need_more_data": "Add at least 2 measurements to view growth chart",
        "weight_change": "Weight (kg)",
        "height_change": "Height (cm)",
        "head_circumference_change": "Head Circ. (cm)",

        // Summary
        "weekly_summary": "Weekly Summary",
        "weekly_stats": "Weekly Stats",
        "feeding": "Feeding",
        "diaper_change": "Diaper Change",
        "weekly_total": "Weekly Total",
        "daily_average": "Daily Avg",
        "trends": "Trends",
        "feeding_amount": "Feeding Amount",
        "sleep_duration_title": "Sleep Duration",
        "ai_analysis": "AI Analysis",
        "get_personalized_advice": "Get personalized parenting advice",
        "same_as_last_week": "Same as last week",
        "increased": "+%@ min",

        // Menu
        "data": "Data",
        "daily_report": "Daily Report",
        "ai_generated_report": "AI-generated health report",
        "history": "History",
        "view_all_records": "View all records",
        "export_data": "Export Data",
        "export_as_csv_pdf": "Export as CSV or PDF",
        "ai_features": "AI Features",
        "smart_qa": "Smart Q&A",
        "ask_ai_questions": "Ask AI parenting questions",
        "smart_reminder": "Smart Reminder",
        "data_based_reminder": "Data-based feeding reminders",
        "settings": "Settings",
        "baby_info": "Baby Info",
        "edit_baby_profile": "Edit baby profile",
        "family_members": "Family Members",
        "manage_family_members": "Manage family members",
        "app_settings": "App Settings",
        "notification_language_theme": "Notifications, language, theme",
        "help_feedback": "Help & Feedback",
        "faq_contact_us": "FAQ, contact us",
        "version": "Version",
        "feature_in_development": "Coming Soon",
        "coming_soon": "%@ coming soon",

        // Settings
        "language": "Language",
        "select_language": "Select Language",

        // Custom Button
        "custom_button": "Custom Button",
        "name": "Name",
        "enter_name": "Enter name",
        "icon": "Icon",
        "color": "Color",

        // Reorder Buttons
        "reorder_buttons": "Reorder Buttons",
        "reset_to_default": "Reset to Default",
        "done": "Done",

        // Errors
        "configuration_error": "Configuration Error",

        // Time
        "minutes_ago": "%d min ago",
        "hours_ago": "%dh ago",
        "hours_minutes_ago": "%dh %dm ago",
        "hours": "h",
        "minutes": "m",
        "times": "x",
        "slept_for": "Slept %@",

        // Age
        "years": "y",
        "months": "m",
        "days": "d",

        // Vaccine Names
        "hepatitis_b": "Hepatitis B",
        "bcg": "BCG",
        "polio": "Polio",
        "dpt": "DPT",
        "mmr": "MMR",
        "japanese_encephalitis": "Japanese Encephalitis",
        "meningococcal_a": "Meningococcal A",
        "hepatitis_a": "Hepatitis A",
    ]
}

// MARK: - Formatted Strings Helper

extension L10n {
    static func format(_ template: String, _ args: CVarArg...) -> String {
        return String(format: template, arguments: args)
    }

    static func ageString(years: Int, months: Int, days: Int) -> String {
        let lang = LanguageManager.shared.currentLanguage
        switch lang {
        case .chinese:
            return "\(years)岁\(months)个月\(days)天"
        case .english:
            return "\(years)y \(months)m \(days)d"
        }
    }

    static func durationString(hours: Int, minutes: Int) -> String {
        let lang = LanguageManager.shared.currentLanguage
        switch lang {
        case .chinese:
            return "\(hours)小时\(minutes)分钟"
        case .english:
            return "\(hours)h \(minutes)m"
        }
    }

    static func shortDurationString(hours: Int, minutes: Int) -> String {
        let lang = LanguageManager.shared.currentLanguage
        switch lang {
        case .chinese:
            return "\(hours)小时\(minutes)分"
        case .english:
            return "\(hours)h \(minutes)m"
        }
    }

    static func timeAgoString(minutes: Int) -> String {
        let lang = LanguageManager.shared.currentLanguage
        if minutes < 60 {
            switch lang {
            case .chinese:
                return "\(minutes)分钟前"
            case .english:
                return "\(minutes) min ago"
            }
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            switch lang {
            case .chinese:
                if mins == 0 {
                    return "\(hours)小时前"
                }
                return "\(hours)小时\(mins)分钟前"
            case .english:
                if mins == 0 {
                    return "\(hours)h ago"
                }
                return "\(hours)h \(mins)m ago"
            }
        }
    }

    static func countString(_ count: Int) -> String {
        let lang = LanguageManager.shared.currentLanguage
        switch lang {
        case .chinese:
            return "\(count)次"
        case .english:
            return "\(count)x"
        }
    }

    static func mlString(_ ml: Int) -> String {
        return "\(ml)ml"
    }

    static func sleptForString(hours: Int, minutes: Int) -> String {
        let lang = LanguageManager.shared.currentLanguage
        let duration = durationString(hours: hours, minutes: minutes)
        switch lang {
        case .chinese:
            return "睡了\(duration)"
        case .english:
            return "Slept \(duration)"
        }
    }

    static func addRecordString(for type: String) -> String {
        let lang = LanguageManager.shared.currentLanguage
        switch lang {
        case .chinese:
            return "添加\(type)记录"
        case .english:
            return "Add \(type) Record"
        }
    }
}
