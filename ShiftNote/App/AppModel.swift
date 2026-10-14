import SwiftUI
import EventKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            SharedStore.save(settings)
            reload()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published private(set) var engine: PayEngine
    @Published private(set) var hasAccess = ShiftRepository.hasAccess
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var now = Date()

    private let repository = ShiftRepository()
    private var observer: NSObjectProtocol?

    init() {
        let s = SharedStore.loadSettings()
        settings = s
        engine = PayEngine(shifts: [], settings: s)
        reload()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    var needsCalendar: Bool { hasAccess && settings.calendarIdentifier == nil }

    func requestAccess() async {
        _ = await repository.requestAccess()
        reload()
        // 初回は「シフト」の予定がいちばん多いカレンダーを自動で選ぶ
        if settings.calendarIdentifier == nil, let guess = guessCalendar() {
            settings.calendarIdentifier = guess
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reload() {
        now = Date()
        hasAccess = ShiftRepository.hasAccess
        calendars = hasAccess ? repository.calendars() : []
        if let id = settings.calendarIdentifier, hasAccess, !calendars.contains(where: { $0.calendarIdentifier == id }) {
            // 選んでいたカレンダーが消えた
            engine = PayEngine(shifts: [], settings: settings)
            return
        }
        engine = PayEngine(shifts: repository.fetchShifts(settings: settings, now: now), settings: settings)
    }

    private func guessCalendar() -> String? {
        var best: (String, Int)?
        for c in calendars {
            var s = settings
            s.calendarIdentifier = c.calendarIdentifier
            let count = repository.fetchShifts(settings: s, now: now).count
            if count > (best?.1 ?? 0) { best = (c.calendarIdentifier, count) }
        }
        return best?.0
    }

    func calendar(for id: String?) -> EKCalendar? {
        calendars.first { $0.calendarIdentifier == id }
    }
}
