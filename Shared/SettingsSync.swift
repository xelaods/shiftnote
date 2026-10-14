import Foundation
import EventKit

/// App Group が使えない署名でも、アプリの設定をウィジェットに渡すための仕組み。
/// 2001年1月1日に終日の予定を1件だけ作り、メモ欄に設定を保存する（ふだんのカレンダー表示には出てこない日付）。
enum CalendarSettingsStore {
    static let title = "Shift Note の設定"
    static let marker = "[shiftnote-settings-v1]"
    static var day: DayKey { DayKey(year: 2001, month: 1, day: 1) }

    private static func events(in store: EKEventStore) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: day.date, end: day.adding(days: 1).date, calendars: nil)
        return store.events(matching: predicate).filter { ($0.notes ?? "").contains(marker) }
    }

    static func read(store: EKEventStore = EKEventStore()) -> AppSettings? {
        guard ShiftRepository.hasAccess else { return nil }
        for event in events(in: store) {
            guard let notes = event.notes,
                  let range = notes.range(of: marker) else { continue }
            let json = notes[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = json.data(using: .utf8),
               let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
                return settings
            }
        }
        return nil
    }

    /// 設定を保存する。sync がオフなら予定を消す
    @discardableResult
    static func write(_ settings: AppSettings, store: EKEventStore) -> Bool {
        guard ShiftRepository.hasAccess else { return false }
        let existing = events(in: store)
        guard settings.syncViaCalendar else {
            for e in existing { try? store.remove(e, span: .thisEvent, commit: false) }
            try? store.commit()
            return true
        }
        guard let data = try? JSONEncoder().encode(settings),
              let json = String(data: data, encoding: .utf8) else { return false }
        let notes = "ウィジェット用の Shift Note の設定です。消すとウィジェットが初期値に戻ります。\n\(marker)\n\(json)"
        let event = existing.first ?? EKEvent(eventStore: store)
        if existing.first == nil {
            let preferred = settings.calendarIdentifier.flatMap { store.calendar(withIdentifier: $0) }
            guard let calendar = (preferred?.allowsContentModifications == true ? preferred : nil)
                    ?? store.defaultCalendarForNewEvents else { return false }
            event.calendar = calendar
            event.title = title
            event.isAllDay = true
            event.startDate = day.date
            event.endDate = day.date
        }
        guard event.notes != notes else { return true }
        event.notes = notes
        do {
            try store.save(event, span: .thisEvent, commit: true)
            // 重複していたら1件にまとめる
            for e in existing.dropFirst() { try? store.remove(e, span: .thisEvent, commit: false) }
            try? store.commit()
            return true
        } catch {
            return false
        }
    }
}
