import SwiftUI
import EventKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    /// スクリーンショット用：見本のシフトで表示する（起動引数 -demo）
    static let isDemo = ProcessInfo.processInfo.arguments.contains("-demo")
    var isDemo: Bool { Self.isDemo }

    enum SyncStatus: Equatable { case idle, saved, failed }

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            SharedStore.save(settings)
            reload()
            scheduleWidgetSync()
        }
    }
    @Published private(set) var engine: PayEngine
    @Published private(set) var hasAccess: Bool
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var now = Date()
    @Published private(set) var syncStatus: SyncStatus = .idle

    private let repository = ShiftRepository()
    private var observer: NSObjectProtocol?
    private var syncTask: Task<Void, Never>?

    init() {
        if Self.isDemo {
            let sample = Sample.engine()
            settings = sample.settings
            engine = sample
            hasAccess = true
            return
        }
        let s = SharedStore.loadSettings()
        settings = s
        engine = PayEngine(shifts: [], settings: s)
        hasAccess = ShiftRepository.hasAccess
        reload()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// ウィジェットが App Group で設定を読めるか
    var widgetsShareSettings: Bool { SharedStore.isShared }

    func requestAccess() async {
        guard !isDemo else { return }
        _ = await repository.requestAccess()
        reload()
        scheduleWidgetSync(immediately: true)
    }

    func reload() {
        now = Date()
        guard !isDemo else { return }
        hasAccess = ShiftRepository.hasAccess
        calendars = hasAccess ? repository.calendars() : []
        if let id = settings.calendarIdentifier, hasAccess, !calendars.contains(where: { $0.calendarIdentifier == id }) {
            engine = PayEngine(shifts: [], settings: settings)
            return
        }
        engine = PayEngine(shifts: repository.fetchShifts(settings: settings, now: now), settings: settings)
    }

    /// 設定をウィジェットへ渡す（App Group が無いときはカレンダー経由）。入力中は少し待ってまとめて保存
    func scheduleWidgetSync(immediately: Bool = false) {
        guard !isDemo else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            if !immediately { try? await Task.sleep(nanoseconds: 900_000_000) }
            guard !Task.isCancelled, let self else { return }
            if self.hasAccess && !SharedStore.isShared {
                self.syncStatus = CalendarSettingsStore.write(self.settings, store: self.repository.store) ? .saved : .failed
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func calendar(for id: String?) -> EKCalendar? {
        calendars.first { $0.calendarIdentifier == id }
    }
}
