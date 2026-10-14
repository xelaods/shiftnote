import Foundation

enum Fmt {
    private static let number: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "ja_JP")
        f.maximumFractionDigits = 0
        return f
    }()

    private static let decimal1: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "ja_JP")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = JST.timeZone
        f.dateFormat = format
        return f
    }

    private static let timeFormatter = formatter("HH:mm")
    private static let monthDayFormatter = formatter("M/d")
    private static let weekdayFormatter = formatter("E")

    /// ¥12,345（1円未満は切り捨て）
    static func yen(_ value: Double) -> String {
        "¥" + (number.string(from: NSNumber(value: (value + 1e-7).rounded(.down))) ?? "0")
    }

    /// 12.3万
    static func man(_ value: Double) -> String {
        let v = (value / 1000).rounded(.down) / 10
        return (decimal1.string(from: NSNumber(value: v)) ?? "0") + "万"
    }

    static func signedYen(_ value: Double) -> String {
        (value >= 0 ? "+" : "−") + yen(abs(value))
    }

    /// 分 → 時間（小数1桁）
    static func hours(_ minutes: Double) -> String {
        decimal1.string(from: NSNumber(value: (minutes / 60 * 10).rounded() / 10)) ?? "0"
    }

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func hour(_ date: Date) -> String { String(Int(time(date).prefix(2)) ?? 0) }
    static func monthDay(_ date: Date) -> String { monthDayFormatter.string(from: date) }
    static func weekday(_ date: Date) -> String { weekdayFormatter.string(from: date) }
    /// 10/14（水）
    static func dayWithWeekday(_ date: Date) -> String { "\(monthDay(date))（\(weekday(date))）" }

    static func weekdaySymbol(_ weekday: Int) -> String {
        ["日", "月", "火", "水", "木", "金", "土"][(weekday - 1 + 7) % 7]
    }

    /// 今日・明日・3日後
    static func relativeDay(_ date: Date, now: Date) -> String {
        let n = DayKey(now).days(to: DayKey(date))
        switch n {
        case ..<0: return "\(-n)日前"
        case 0: return "今日"
        case 1: return "明日"
        case 2: return "明後日"
        default: return "\(n)日後"
        }
    }
}
