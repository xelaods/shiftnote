import Foundation

struct PayBreakdown: Equatable, Hashable {
    var total: Double = 0
    var base: Double = 0
    var night: Double = 0
    var nightMinutes: Double = 0
    var paidMinutes: Double = 0
    var restMinutes: Double = 0
    var transport: Double = 0
}

/// 1シフトの給与計算。Scriptable版 Shift Note と同じ式で、1分ずつ時給と深夜割増を足していく。
enum PayCalculator {
    static func restMinutes(for minutes: Double, rates: PayRates) -> Double {
        if minutes >= 480 { return rates.break8 }
        if minutes >= 420 { return rates.break7 }
        if minutes >= 360 { return rates.break6 }
        return 0
    }

    static func breakdown(start: Date, end: Date, rates: PayRates) -> PayBreakdown {
        let s = start.timeIntervalSince1970
        let e = end.timeIntervalSince1970
        let minutes = (e - s) / 60
        guard minutes > 0 else { return PayBreakdown() }
        let rest = restMinutes(for: minutes, rates: rates)
        let paid = max(0, minutes - rest)
        // 休憩は勤務時間全体から按分して引く
        let ratio = paid / minutes
        var base = 0.0, night = 0.0, nightMinutes = 0.0
        var t = s
        while t < e {
            let slice = min(60, e - t) / 60
            let local = t + JST.offset
            let dayIndex = (local / 86400).rounded(.down)
            let weekday = ((Int(dayIndex) + 4) % 7 + 7) % 7   // 0 = 日曜
            let hour = Int((local - dayIndex * 86400) / 3600)
            let rate = weekday == 0 ? rates.sunday : weekday == 6 ? rates.saturday : rates.weekday
            let amount = rate * slice / 60 * ratio
            base += amount
            if hour >= 22 || hour < 5 {
                night += amount * rates.nightPremium / 100
                nightMinutes += slice * ratio
            }
            t += 60
        }
        return PayBreakdown(total: base + night + rates.transport, base: base, night: night,
                            nightMinutes: nightMinutes, paidMinutes: paid, restMinutes: rest, transport: rates.transport)
    }
}
