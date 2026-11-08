import Foundation
import EventKit

struct ShifconCalendarShift: Hashable {
    let sourceID: String
    let start: Date
    let end: Date
}

struct ShifconCalendarSyncResult {
    let created: Int
    let updated: Int
    let removed: Int
}

enum ShifconCalendarSyncError: Error {
    case calendarPermissionRequired
    case invalidSnapshot
    case noWritableCalendar
}

/// Reconciles a complete five-date snapshot from Shifcon's currently loaded request screen.
/// Never changes events not owned by Shift Note.
final class ShifconCalendarWriter {
    private let store: EKEventStore
    private let marker = "shiftnote-shifcon:"
    private let legacyMarker = "shiftnote-confirmed:"
    private let calendarTitle = "Shift Note"

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func reconcile(_ shifts: [ShifconCalendarShift], completeSnapshot: Bool,
                   eventTitle: String = "シフト", now: Date = Date()) throws -> ShifconCalendarSyncResult {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw ShifconCalendarSyncError.calendarPermissionRequired
        }
        guard completeSnapshot else { throw ShifconCalendarSyncError.invalidSnapshot }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let from = cal.startOfDay(for: now)
        guard let until = cal.date(byAdding: .day, value: 5, to: from) else {
            throw ShifconCalendarSyncError.invalidSnapshot
        }
        let searchUntil = until.addingTimeInterval(5 * 60 * 60)
        let identifiers = shifts.map(\.sourceID)
        guard Set(identifiers).count == identifiers.count,
              shifts.allSatisfy({
                  !$0.sourceID.isEmpty && !$0.sourceID.contains("\n") &&
                  $0.start >= from && $0.start < searchUntil &&
                  $0.end > $0.start && $0.end.timeIntervalSince($0.start) <= 86400
              }) else {
            throw ShifconCalendarSyncError.invalidSnapshot
        }

        let target = try ownedCalendar()
        let query = store.predicateForEvents(withStart: from, end: searchUntil, calendars: [target])
        let managed = store.events(matching: query).filter {
            isManagedNotes($0.notes) &&
            $0.startDate >= from && $0.startDate < searchUntil
        }
        var byID = Dictionary(grouping: managed, by: { managedSourceID($0.notes) ?? "" })
        var created = 0
        var updated = 0
        var removed = 0

        for shift in shifts {
            var events = byID.removeValue(forKey: shift.sourceID) ?? []
            let event = events.isEmpty ? EKEvent(eventStore: store) : events.removeFirst()
            let isNew = event.eventIdentifier == nil
            let note = marker + shift.sourceID
            if isNew || event.startDate != shift.start || event.endDate != shift.end ||
                event.title != eventTitle || event.notes != note {
                event.calendar = target
                event.title = eventTitle
                event.startDate = shift.start
                event.endDate = shift.end
                event.notes = note
                try store.save(event, span: .thisEvent)
                if isNew { created += 1 } else { updated += 1 }
            }
            for duplicate in events {
                try store.remove(duplicate, span: .thisEvent)
                removed += 1
            }
        }
        for obsolete in byID.values.flatMap({ $0 }) {
            try store.remove(obsolete, span: .thisEvent)
            removed += 1
        }
        return ShifconCalendarSyncResult(created: created, updated: updated, removed: removed)
    }

    private func isManagedNotes(_ notes: String?) -> Bool {
        guard let notes else { return false }
        return notes.hasPrefix(marker) || notes.hasPrefix(legacyMarker)
    }

    private func managedSourceID(_ notes: String?) -> String? {
        guard let notes else { return nil }
        if notes.hasPrefix(marker) { return String(notes.dropFirst(marker.count)) }
        if notes.hasPrefix(legacyMarker) { return String(notes.dropFirst(legacyMarker.count)) }
        return nil
    }

    private func ownedCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: {
            $0.title == calendarTitle && $0.allowsContentModifications
        }) { return existing }
        guard let source = store.defaultCalendarForNewEvents?.source ??
            store.sources.first(where: { $0.sourceType == .local || $0.sourceType == .calDAV }) else {
            throw ShifconCalendarSyncError.noWritableCalendar
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
}

/// Builds a safe, complete snapshot for the five JST dates starting today.
/// A missing, duplicate, or malformed date makes the snapshot unusable, so callers
/// must leave the existing calendar events untouched. Uses the values loaded into
/// the current Shifcon request form before the user edits them.
enum ShifconCalendarSnapshot {
    static let dayCount = 5

    static func make(from period: RequestPeriod, now: Date = Date()) -> [ShifconCalendarShift]? {
        let firstDay = DayKey(now)
        let targetDays = (0..<dayCount).map { firstDay.adding(days: $0) }
        let grouped = Dictionary(grouping: period.days, by: \.date)
        guard targetDays.allSatisfy({ grouped[$0]?.count == 1 }) else { return nil }

        var shifts: [ShifconCalendarShift] = []
        for date in targetDays {
            guard let day = grouped[date]?.first else { return nil }
            let fields = day.fields
            if fields.shiftType == "2" { continue }
            guard fields.shiftType == "1",
                  let startClock = fields.start,
                  let endClock = fields.end,
                  endClock > startClock,
                  endClock.totalMinutes - startClock.totalMinutes <= 24 * 60,
                  let start = JST.gregorian.date(byAdding: .minute, value: startClock.totalMinutes, to: date.date),
                  let end = JST.gregorian.date(byAdding: .minute, value: endClock.totalMinutes, to: date.date),
                  end > start else { return nil }
            shifts.append(ShifconCalendarShift(sourceID: "date-\(date.id)", start: start, end: end))
        }
        return shifts
    }
}
