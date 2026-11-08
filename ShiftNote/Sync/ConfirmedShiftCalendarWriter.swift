import Foundation
import EventKit

struct ConfirmedShift: Hashable {
    let sourceID: String
    let start: Date
    let end: Date
}

struct ConfirmedShiftSyncResult {
    let created: Int
    let updated: Int
    let removed: Int
}

enum ConfirmedShiftSyncError: Error {
    case calendarPermissionRequired
    case invalidSnapshot
    case noWritableCalendar
}

/// Accepts only an authoritative complete five-day snapshot of confirmed shifts.
/// Never changes events not owned by Shift Note.
final class ConfirmedShiftCalendarWriter {
    private let store: EKEventStore
    private let marker = "shiftnote-confirmed:"
    private let calendarTitle = "Shift Note"

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func reconcile(_ shifts: [ConfirmedShift], completeSnapshot: Bool,
                   eventTitle: String = "シフト", now: Date = Date()) throws -> ConfirmedShiftSyncResult {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw ConfirmedShiftSyncError.calendarPermissionRequired
        }
        guard completeSnapshot else { throw ConfirmedShiftSyncError.invalidSnapshot }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let from = cal.startOfDay(for: now)
        guard let until = cal.date(byAdding: .day, value: 5, to: from) else {
            throw ConfirmedShiftSyncError.invalidSnapshot
        }
        let identifiers = shifts.map(\.sourceID)
        guard Set(identifiers).count == identifiers.count,
              shifts.allSatisfy({
                  !$0.sourceID.isEmpty && !$0.sourceID.contains("\n") &&
                  $0.start >= from && $0.start < until &&
                  $0.end > $0.start && $0.end.timeIntervalSince($0.start) <= 86400
              }) else {
            throw ConfirmedShiftSyncError.invalidSnapshot
        }

        let target = try ownedCalendar()
        let query = store.predicateForEvents(withStart: from, end: until, calendars: [target])
        let managed = store.events(matching: query).filter {
            ($0.notes ?? "").hasPrefix(marker)
        }
        var byID = Dictionary(grouping: managed, by: {
            String(($0.notes ?? "").dropFirst(marker.count))
        })
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
        return ConfirmedShiftSyncResult(created: created, updated: updated, removed: removed)
    }

    private func ownedCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: {
            $0.title == calendarTitle && $0.allowsContentModifications
        }) { return existing }
        guard let source = store.defaultCalendarForNewEvents?.source ??
            store.sources.first(where: { $0.sourceType == .local || $0.sourceType == .calDAV }) else {
            throw ConfirmedShiftSyncError.noWritableCalendar
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
}
