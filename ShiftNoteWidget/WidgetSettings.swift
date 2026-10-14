import AppIntents
import WidgetKit

/// ウィジェットの編集画面で入れる給与の条件（アプリと設定を共有できないとき用）
protocol PaySettingsIntent {
    var eventTitle: String { get }
    var weekday: Int { get }
    var saturday: Int { get }
    var sunday: Int { get }
    var nightPremium: Int { get }
    var transport: Int { get }
    var closingDay: Int { get }
    var payOffset: Int { get }
}

extension PaySettingsIntent {
    var settings: AppSettings {
        var s = AppSettings()
        let title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        s.eventTitle = title.isEmpty ? "シフト" : title
        s.rates.weekday = Double(weekday)
        s.rates.saturday = Double(saturday)
        s.rates.sunday = Double(sunday)
        s.rates.nightPremium = Double(nightPremium)
        s.rates.transport = Double(transport)
        s.closingDay = min(28, max(0, closingDay))
        s.payOffset = min(2, max(0, payOffset))
        return s
    }
}

struct PayWidgetIntent: WidgetConfigurationIntent, PaySettingsIntent {
    static var title: LocalizedStringResource = "給与の条件"
    static var description = IntentDescription("時給などはアプリと同じ値を入れてください。")

    @Parameter(title: "予定の名前", default: "シフト") var eventTitle: String
    @Parameter(title: "平日の時給", default: 1350) var weekday: Int
    @Parameter(title: "土曜の時給", default: 1400) var saturday: Int
    @Parameter(title: "日曜の時給", default: 1450) var sunday: Int
    @Parameter(title: "深夜割増（%）", default: 25) var nightPremium: Int
    @Parameter(title: "交通費（1回）", default: 0) var transport: Int
    @Parameter(title: "締め日（末日は0）", default: 0) var closingDay: Int
    @Parameter(title: "支給（当月0・翌月1・翌々月2）", default: 1) var payOffset: Int

    init() {}
}
