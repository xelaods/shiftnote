import Foundation
import EventKit

/// iPhoneのカレンダーから「シフト」の予定を読む
final class ShiftRepository {
    let store = EKEventStore()

    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static var accessDenied: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        return s == .denied || s == .restricted || s == .writeOnly
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func calendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
    }

    /// 前年1月〜翌年3月を読む（前年との比較と、給料日ベースの集計のため）
    static func range(now: Date) -> (Date, Date) {
        let year = DayKey(now).year
        let from = DayKey(year: year - 1, month: 1, day: 1).date
        let to = DayKey(year: year + 1, month: 4, day: 1).date
        return (from, to)
    }

    func fetchShifts(settings: AppSettings, now: Date = Date()) -> [Shift] {
        guard Self.hasAccess else { return [] }
        // カレンダーを選んでいなければ、すべてのカレンダーから探す
        let targets: [EKCalendar]
        if let id = settings.calendarIdentifier {
            guard let calendar = store.calendar(withIdentifier: id) else { return [] }
            targets = [calendar]
        } else {
            targets = store.calendars(for: .event)
        }
        guard !targets.isEmpty else { return [] }
        let (from, to) = Self.range(now: now)
        let title = settings.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: targets)
        var seen = Set<String>()
        var shifts: [Shift] = []
        for event in store.events(matching: predicate) {
            guard (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == title,
                  !event.isAllDay,
                  let s = event.startDate, let e = event.endDate,
                  e > s, e.timeIntervalSince(s) <= 86400 else { continue }
            let shift = Shift(start: s, end: e)
            // 同じ時刻の重複は1件として数える
            if seen.insert(shift.id).inserted { shifts.append(shift) }
        }
        return shifts.sorted { $0.start < $1.start }
    }
}

enum LoadState {
    case ready(PayEngine)
    case message(String)
}

/// ウィジェット用：カレンダーと設定を読んで計算する
enum DataLoader {
    /// - Parameter widgetSettings: ウィジェットの編集画面で入れた時給など。
    ///   アプリと設定を共有できる（App Group が使える）ときはアプリの設定を優先する。
    static func load(now: Date = Date(), widgetSettings: AppSettings) -> LoadState {
        guard ShiftRepository.hasAccess else {
            return .message("Shift Noteを開いて、カレンダーへのアクセスを許可してください")
        }
        let settings = SharedStore.isShared ? SharedStore.loadSettings() : widgetSettings
        let shifts = ShiftRepository().fetchShifts(settings: settings, now: now)
        return .ready(PayEngine(shifts: shifts, settings: settings))
    }
}
