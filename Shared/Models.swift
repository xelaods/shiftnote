import Foundation

/// 給与の条件（Scriptable版 Shift Note と同じ項目）
struct PayRates: Codable, Equatable, Hashable {
    var weekday: Double = 1350
    var saturday: Double = 1400
    var sunday: Double = 1450
    /// 深夜（22時〜5時）の割増率（%）
    var nightPremium: Double = 25
    /// 1シフトあたりの交通費
    var transport: Double = 0
    /// 勤務時間が6・7・8時間以上のときの休憩（分）
    var break6: Double = 30
    var break7: Double = 45
    var break8: Double = 60

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PayRates()
        weekday = try c.decodeIfPresent(Double.self, forKey: .weekday) ?? d.weekday
        saturday = try c.decodeIfPresent(Double.self, forKey: .saturday) ?? d.saturday
        sunday = try c.decodeIfPresent(Double.self, forKey: .sunday) ?? d.sunday
        nightPremium = try c.decodeIfPresent(Double.self, forKey: .nightPremium) ?? d.nightPremium
        transport = try c.decodeIfPresent(Double.self, forKey: .transport) ?? d.transport
        break6 = try c.decodeIfPresent(Double.self, forKey: .break6) ?? d.break6
        break7 = try c.decodeIfPresent(Double.self, forKey: .break7) ?? d.break7
        break8 = try c.decodeIfPresent(Double.self, forKey: .break8) ?? d.break8
    }
}

enum WeekStart: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    var id: Int { rawValue }
    var label: String { self == .sunday ? "日曜日" : "月曜日" }
}

struct AppSettings: Codable, Equatable {
    /// シフトを読むカレンダー
    var calendarIdentifier: String?
    /// この名前の予定をシフトとして読む
    var eventTitle: String = "シフト"
    var rates = PayRates()
    /// 給料の締め日（0 = 末日）
    var closingDay: Int = 0
    /// 支給月（0 = 当月, 1 = 翌月, 2 = 翌々月）
    var payOffset: Int = 1
    var weekStart: WeekStart = .sunday
    /// App Group が使えないとき、設定をカレンダー（2001年1月1日の予定）に保存してウィジェットと共有する
    var syncViaCalendar: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        calendarIdentifier = try c.decodeIfPresent(String.self, forKey: .calendarIdentifier)
        eventTitle = try c.decodeIfPresent(String.self, forKey: .eventTitle) ?? d.eventTitle
        rates = try c.decodeIfPresent(PayRates.self, forKey: .rates) ?? d.rates
        closingDay = try c.decodeIfPresent(Int.self, forKey: .closingDay) ?? d.closingDay
        payOffset = try c.decodeIfPresent(Int.self, forKey: .payOffset) ?? d.payOffset
        weekStart = try c.decodeIfPresent(WeekStart.self, forKey: .weekStart) ?? d.weekStart
        syncViaCalendar = try c.decodeIfPresent(Bool.self, forKey: .syncViaCalendar) ?? d.syncViaCalendar
    }
}

struct Shift: Identifiable, Hashable {
    let start: Date
    let end: Date
    var id: String { "\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))" }
}
