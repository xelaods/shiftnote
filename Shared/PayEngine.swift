import Foundation

struct ShiftItem: Identifiable, Hashable {
    let shift: Shift
    let pay: PayBreakdown
    /// 勤務した日（開始日）
    let workDay: DayKey
    /// 給料が支払われる月
    let payMonth: MonthKey

    var id: String { shift.id }
    var start: Date { shift.start }
    var end: Date { shift.end }
}

enum Basis: String, CaseIterable, Identifiable {
    case work, pay
    var id: String { rawValue }
    var label: String { self == .work ? "働いた月" : "給料日の月" }
}

struct MonthStats {
    var total = 0.0
    var done = 0.0
    var base = 0.0
    var night = 0.0
    var nightMinutes = 0.0
    var paidMinutes = 0.0
    var transport = 0.0
    var shiftCount = 0
    var days = 0

    init() {}

    init(items: [ShiftItem], now: Date) {
        for i in items {
            total += i.pay.total
            if i.end <= now { done += i.pay.total }
            base += i.pay.base
            night += i.pay.night
            nightMinutes += i.pay.nightMinutes
            paidMinutes += i.pay.paidMinutes
            transport += i.pay.transport
        }
        shiftCount = items.count
        days = Set(items.map(\.workDay)).count
    }

    var planned: Double { max(0, total - done) }
    var progress: Double { total > 0 ? min(1, done / total) : 0 }
    /// 交通費を除いた、実働1時間あたりの給与
    var effectiveHourly: Double? { paidMinutes > 0 ? (total - transport) / (paidMinutes / 60) : nil }
    var averageMinutesPerDay: Double? { days > 0 ? paidMinutes / Double(days) : nil }
}

/// 年収の壁（2026年分の目安）
struct IncomeWall: Identifiable, Hashable {
    let amount: Double
    let title: String
    let short: String
    let who: String
    /// 社会保険の判定は交通費込み、税金は交通費（通勤手当）を除く
    let includesTransport: Bool
    var id: Double { amount }

    static let all: [IncomeWall] = [
        IncomeWall(amount: 1_100_000, title: "住民税がかかり始める", short: "住民税", who: "本人・自治体により約110〜119万円", includesTransport: false),
        IncomeWall(amount: 1_300_000, title: "社会保険の扶養から外れる", short: "社保", who: "本人・19歳未満または23歳以上", includesTransport: true),
        IncomeWall(amount: 1_500_000, title: "社会保険の扶養から外れる", short: "社保", who: "本人・19〜22歳", includesTransport: true),
        IncomeWall(amount: 1_590_000, title: "親の控除が減り始める", short: "親の控除", who: "親・19〜22歳の子の特定親族特別控除", includesTransport: false),
        IncomeWall(amount: 1_780_000, title: "所得税がかかり始める", short: "所得税", who: "本人", includesTransport: false)
    ]
}

struct WallStatus: Identifiable, Hashable {
    let wall: IncomeWall
    /// この壁の判定に使う額
    let value: Double
    var id: Double { wall.amount }
    var remaining: Double { wall.amount - value }
    var isOver: Bool { remaining <= 0 }
    var progress: Double { min(1, max(0, value / wall.amount)) }
}

struct PayEngine {
    let settings: AppSettings
    let items: [ShiftItem]

    init(shifts: [Shift], settings: AppSettings) {
        self.settings = settings
        self.items = shifts.sorted { $0.start < $1.start }.map { s in
            let day = DayKey(s.start)
            let carry = (settings.closingDay > 0 && day.day > settings.closingDay) ? 1 : 0
            let payMonth = MonthKey(year: day.year, month: day.month + carry + settings.payOffset)
            return ShiftItem(shift: s, pay: PayCalculator.breakdown(start: s.start, end: s.end, rates: settings.rates),
                             workDay: day, payMonth: payMonth)
        }
    }

    func monthKey(of item: ShiftItem, basis: Basis) -> MonthKey {
        basis == .work ? item.workDay.monthKey : item.payMonth
    }

    func items(in month: MonthKey, basis: Basis) -> [ShiftItem] {
        items.filter { monthKey(of: $0, basis: basis) == month }
    }

    func stats(for month: MonthKey, basis: Basis = .work, now: Date) -> MonthStats {
        MonthStats(items: items(in: month, basis: basis), now: now)
    }

    func months(of year: Int, basis: Basis = .work, now: Date) -> [MonthStats] {
        var buckets = Array(repeating: [ShiftItem](), count: 12)
        for i in items {
            let m = monthKey(of: i, basis: basis)
            if m.year == year { buckets[m.month - 1].append(i) }
        }
        return buckets.map { MonthStats(items: $0, now: now) }
    }

    func yearStats(_ year: Int, basis: Basis = .work, now: Date) -> MonthStats {
        MonthStats(items: items.filter { monthKey(of: $0, basis: basis).year == year }, now: now)
    }

    /// 過ぎた月（今月より前）で、給与があった月の平均
    func monthlyAverage(year: Int, basis: Basis = .work, now: Date) -> Double? {
        let current = MonthKey(now)
        let past = months(of: year, basis: basis, now: now).enumerated()
            .filter { MonthKey(year: year, month: $0.offset + 1) < current && $0.element.total > 0 }
        guard !past.isEmpty else { return nil }
        return past.map(\.element.total).reduce(0, +) / Double(past.count)
    }

    func walls(year: Int, now: Date) -> (total: Double, transport: Double, statuses: [WallStatus]) {
        let s = yearStats(year, basis: .pay, now: now)
        let statuses = IncomeWall.all.map { w in
            WallStatus(wall: w, value: w.includesTransport ? s.total : s.total - s.transport)
        }
        return (s.total, s.transport, statuses)
    }

    var byDay: [DayKey: [ShiftItem]] { Dictionary(grouping: items, by: \.workDay) }

    func items(on day: DayKey) -> [ShiftItem] { items.filter { $0.workDay == day } }

    func next(after now: Date) -> ShiftItem? { items.first { $0.end > now } }

    func upcoming(after now: Date, limit: Int) -> [ShiftItem] {
        Array(items.filter { $0.end > now }.prefix(limit))
    }

    func summary(of days: [DayKey], now: Date) -> MonthStats {
        let set = Set(days)
        return MonthStats(items: items.filter { set.contains($0.workDay) }, now: now)
    }

    var years: [Int] {
        var set = Set(items.map(\.workDay.year))
        set.insert(DayKey(Date()).year)
        return set.sorted()
    }
}
