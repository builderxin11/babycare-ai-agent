import Foundation

/// Mock data for testing UI without backend connection
class MockDataService {
    static let shared = MockDataService()

    // MARK: - Mock Baby

    var mockBaby: Baby {
        Baby(
            id: "mock-baby-1",
            familyId: "mock-family-1",
            name: "小明",
            birthDate: Calendar.current.date(byAdding: .month, value: -12, to: Date())!,
            gender: .male,
            notes: "健康快乐的宝宝"
        )
    }

    // MARK: - Mock Physiology Logs

    var mockLogs: [PhysiologyLog] {
        let calendar = Calendar.current
        let today = Date()

        return [
            // Today's logs
            PhysiologyLog(
                id: "log-1",
                babyId: "mock-baby-1",
                type: .sleep,
                startTime: calendar.date(bySettingHour: 12, minute: 50, second: 0, of: today)!
            ),
            PhysiologyLog(
                id: "log-2",
                babyId: "mock-baby-1",
                type: .sleep,
                startTime: calendar.date(bySettingHour: 13, minute: 55, second: 0, of: today)!,
                endTime: calendar.date(bySettingHour: 13, minute: 55, second: 0, of: today)!,
                notes: "起床"
            ),
            PhysiologyLog(
                id: "log-3",
                babyId: "mock-baby-1",
                type: .diaperDirty,
                startTime: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: today)!,
                notes: "大/软/茶色"
            ),
            PhysiologyLog(
                id: "log-4",
                babyId: "mock-baby-1",
                type: .milkSolid,
                startTime: calendar.date(bySettingHour: 16, minute: 30, second: 0, of: today)!,
                notes: "燕麦粉 10g 野牛肉 30g 苹果梨泥 30g 山药泥 30g"
            ),
            PhysiologyLog(
                id: "log-5",
                babyId: "mock-baby-1",
                type: .diaperDirty,
                startTime: calendar.date(bySettingHour: 17, minute: 45, second: 0, of: today)!
            ),
            PhysiologyLog(
                id: "log-6",
                babyId: "mock-baby-1",
                type: .milkFormula,
                startTime: calendar.date(bySettingHour: 18, minute: 40, second: 0, of: today)!,
                amount: 120,
                unit: .ml
            ),
            PhysiologyLog(
                id: "log-7",
                babyId: "mock-baby-1",
                type: .milkFormula,
                startTime: calendar.date(bySettingHour: 18, minute: 55, second: 0, of: today)!,
                amount: 190,
                unit: .ml
            ),
            PhysiologyLog(
                id: "log-8",
                babyId: "mock-baby-1",
                type: .sleep,
                startTime: calendar.date(bySettingHour: 19, minute: 35, second: 0, of: today)!
            ),
        ]
    }

    // MARK: - Mock Context Events

    var mockEvents: [ContextEvent] {
        [
            ContextEvent(
                id: "event-1",
                babyId: "mock-baby-1",
                type: .vaccine,
                title: "12月龄疫苗",
                startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            ),
            ContextEvent(
                id: "event-2",
                babyId: "mock-baby-1",
                type: .milestone,
                title: "会叫妈妈了",
                startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            ),
        ]
    }

    // MARK: - Mock AI Response

    var mockAdvice: ParentingAdvice {
        ParentingAdvice(
            question: "宝宝打疫苗后食欲下降正常吗？",
            summary: "疫苗接种后食欲下降是常见的正常反应。宝宝的免疫系统正在努力工作以建立保护，这可能会导致轻微不适并影响食欲，通常持续24-72小时。",
            keyPoints: [
                "[医学] 疫苗后食欲下降通常在48-72小时内恢复正常",
                "[数据] 您宝宝的进食量比7天基线下降了20%",
                "[社区] 很多家长反映类似经历，大多数在第3天看到改善"
            ],
            actionItems: [
                "提供额外的安慰和拥抱",
                "如果儿科医生建议，可以考虑使用对乙酰氨基酚",
                "监测体温是否超过38.5°C"
            ],
            riskLevel: .low,
            confidenceScore: 0.85,
            citations: [
                Citation(sourceType: "medical", reference: "AAP 免疫接种指南", detail: nil),
                Citation(sourceType: "data_analysis", reference: "7天趋势分析", detail: nil),
                Citation(sourceType: "xhs_post", reference: "小红书共识 (8篇帖子)", detail: nil)
            ],
            sourcesUsed: [
                SourceStatus(source: "医学知识库", status: .ok, message: "获取了相关免疫接种指南"),
                SourceStatus(source: "数据分析", status: .ok, message: "分析了7天的喂养数据"),
                SourceStatus(source: "社区洞察", status: .ok, message: "找到8个相关社区讨论")
            ]
        )
    }

    // MARK: - Mock Daily Report

    var mockReport: DailyReport {
        DailyReport(
            babyId: "mock-baby-1",
            babyName: "小明",
            reportDate: Date(),
            healthStatus: .healthy,
            confidenceScore: 0.87,
            trendDirection: .improving,
            summary: "小明今天状态很好！疫苗接种后喂养量已恢复正常。睡眠模式继续改善。",
            observations: [
                "喂养量恢复到520ml，比昨天的480ml有所增加",
                "睡眠时长比基线增加了30分钟",
                "规律换尿布表明水分充足"
            ],
            actionItems: [
                "继续当前的喂养计划",
                "考虑将睡前程序提前15分钟"
            ],
            warnings: [
                "继续观察是否有疫苗相关症状残留"
            ],
            dataSnapshot: [
                "feeding_ml": AnyCodable(520.0),
                "sleep_min": AnyCodable(840.0),
                "diaper_count": AnyCodable(8)
            ],
            baselineSnapshot: [
                "feeding_ml": AnyCodable(500.0),
                "sleep_min": AnyCodable(810.0),
                "diaper_count": AnyCodable(7)
            ]
        )
    }
}

// MARK: - Preview Helpers

extension Baby {
    static var preview: Baby {
        MockDataService.shared.mockBaby
    }
}

extension PhysiologyLog {
    static var previews: [PhysiologyLog] {
        MockDataService.shared.mockLogs
    }
}

extension ParentingAdvice {
    static var preview: ParentingAdvice {
        MockDataService.shared.mockAdvice
    }
}

extension DailyReport {
    static var preview: DailyReport {
        MockDataService.shared.mockReport
    }
}
