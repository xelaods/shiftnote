import Foundation

/// ウィジェットの見本表示用のシフト
enum Sample {
    static func engine(now: Date = Date()) -> PayEngine {
        var settings = AppSettings()
        settings.calendarIdentifier = "sample"
        settings.rates.transport = 300
        let today = DayKey(now)
        var shifts: [Shift] = []
        for offset in -120...45 {
            let day = today.adding(days: offset)
            let pattern = (day.id * 7 + offset) % 5
            let (startHour, length): (Int, Double)
            switch day.weekday {
            case 2, 4: (startHour, length) = (17, 5)
            case 6: (startHour, length) = (18, 5.5)
            case 7: (startHour, length) = (10, 8)
            default: continue
            }
            if pattern == 0 { continue }
            let start = day.date.addingTimeInterval(Double(startHour) * 3600)
            shifts.append(Shift(start: start, end: start.addingTimeInterval(length * 3600)))
        }
        return PayEngine(shifts: shifts, settings: settings)
    }
}
