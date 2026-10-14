import WidgetKit
import SwiftUI
import AppIntents

@main
struct ShiftNoteWidgets: WidgetBundle {
    var body: some Widget {
        NextShiftWidget()
        MonthPayWidget()
        IncomeWidget()
        ShiftCalendarWidget()
    }
}

// MARK: - データ

struct PayEntry: TimelineEntry {
    let date: Date
    let state: LoadState
}

/// 次に表示が変わる時刻（シフトの開始・終了、日付の変わり目、最長30分）
func nextRefresh(after now: Date, state: LoadState) -> Date {
    var candidates = [now.addingTimeInterval(30 * 60), DayKey(now).adding(days: 1).date]
    if case .ready(let engine) = state, let next = engine.next(after: now) {
        candidates.append(next.start > now ? next.start : next.end)
    }
    return candidates.filter { $0 > now }.min() ?? now.addingTimeInterval(1800)
}

struct PayProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PayEntry {
        PayEntry(date: Date(), state: .ready(Sample.engine()))
    }

    func snapshot(for configuration: PayWidgetIntent, in context: Context) async -> PayEntry {
        let now = Date()
        if context.isPreview { return PayEntry(date: now, state: .ready(Sample.engine(now: now))) }
        let state = DataLoader.load(now: now, widgetSettings: configuration.settings)
        if case .message = state { return PayEntry(date: now, state: .ready(Sample.engine(now: now))) }
        return PayEntry(date: now, state: state)
    }

    func timeline(for configuration: PayWidgetIntent, in context: Context) async -> Timeline<PayEntry> {
        let now = Date()
        let state = DataLoader.load(now: now, widgetSettings: configuration.settings)
        return Timeline(entries: [PayEntry(date: now, state: state)], policy: .after(nextRefresh(after: now, state: state)))
    }
}

extension View {
    func widgetBackground() -> some View {
        containerBackground(for: .widget) { Theme.card }
    }
}

/// 状態に応じて中身かメッセージを出す
struct EntryView<Content: View>: View {
    let state: LoadState
    @ViewBuilder let content: (PayEngine, WidgetFamily) -> Content
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch state {
        case .message(let text): WidgetMessageView(text: text, family: family)
        case .ready(let engine): content(engine, family)
        }
    }
}

// MARK: - ウィジェット

struct NextShiftWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "NextShift", intent: PayWidgetIntent.self, provider: PayProvider()) { entry in
            EntryView(state: entry.state) { engine, family in
                NextShiftWidgetView(engine: engine, now: entry.date, family: family)
            }
            .widgetBackground()
            .widgetURL(URL(string: "shiftnote://home"))
        }
        .configurationDisplayName("次のシフト")
        .description("次のシフトの時間と給与。勤務中は終わりまでの残り時間を表示します。")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct MonthPayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "MonthPay", intent: PayWidgetIntent.self, provider: PayProvider()) { entry in
            EntryView(state: entry.state) { engine, family in
                MonthPayWidgetView(engine: engine, now: entry.date, family: family)
            }
            .widgetBackground()
            .widgetURL(URL(string: "shiftnote://home"))
        }
        .configurationDisplayName("今月の給与")
        .description("今月の予想給与と勤務時間を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct IncomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Income", intent: PayWidgetIntent.self, provider: PayProvider()) { entry in
            EntryView(state: entry.state) { engine, family in
                IncomeWidgetView(engine: engine, now: entry.date, family: family)
            }
            .widgetBackground()
            .widgetURL(URL(string: "shiftnote://income"))
        }
        .configurationDisplayName("年収と年収の壁")
        .description("今年の年収の見込みと、年収の壁までの残りを表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - シフトカレンダー

struct CalendarEntry: TimelineEntry {
    let date: Date
    let state: LoadState
    let span: CalendarSpanKind
}

struct CalendarProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date(), state: .ready(Sample.engine()), span: .weekCentered)
    }

    func snapshot(for configuration: ShiftCalendarIntent, in context: Context) async -> CalendarEntry {
        let now = Date()
        let span = configuration.span.kind
        if context.isPreview { return CalendarEntry(date: now, state: .ready(Sample.engine(now: now)), span: span) }
        let state = DataLoader.load(now: now, widgetSettings: configuration.calendarSettings)
        if case .message = state { return CalendarEntry(date: now, state: .ready(Sample.engine(now: now)), span: span) }
        return CalendarEntry(date: now, state: state, span: span)
    }

    func timeline(for configuration: ShiftCalendarIntent, in context: Context) async -> Timeline<CalendarEntry> {
        let now = Date()
        let state = DataLoader.load(now: now, widgetSettings: configuration.calendarSettings)
        return Timeline(entries: [CalendarEntry(date: now, state: state, span: configuration.span.kind)],
                        policy: .after(nextRefresh(after: now, state: state)))
    }
}

struct ShiftCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ShiftCalendar", intent: ShiftCalendarIntent.self, provider: CalendarProvider()) { entry in
            EntryView(state: entry.state) { engine, family in
                CalendarWidgetView(engine: engine, now: entry.date, family: family, span: entry.span)
            }
            .widgetBackground()
            .widgetURL(URL(string: "shiftnote://calendar"))
        }
        .configurationDisplayName("シフトカレンダー")
        .description("シフトをカレンダーで表示します。長押しして「ウィジェットを編集」で期間を変えられます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
