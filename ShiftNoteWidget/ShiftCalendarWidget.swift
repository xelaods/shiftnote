import WidgetKit
import SwiftUI
import AppIntents

enum CalendarSpan: String, AppEnum {
    case weekCentered
    case weekFromToday
    case thisWeek
    case twoWeeks
    case month

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "表示する期間"
    static var caseDisplayRepresentations: [CalendarSpan: DisplayRepresentation] = [
        .weekCentered: "1週間（今日を真ん中）",
        .weekFromToday: "1週間（今日から）",
        .thisWeek: "今週",
        .twoWeeks: "2週間",
        .month: "1か月"
    ]
}

struct ShiftCalendarIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "シフトカレンダー"
    static var description = IntentDescription("カレンダーに表示する期間を選べます。")

    @Parameter(title: "期間", default: .weekCentered)
    var span: CalendarSpan

    init() {}
}

struct CalendarEntry: TimelineEntry {
    let date: Date
    let state: LoadState
    let span: CalendarSpan
}

struct CalendarProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date(), state: .ready(Sample.engine()), span: .weekCentered)
    }

    func snapshot(for configuration: ShiftCalendarIntent, in context: Context) async -> CalendarEntry {
        let now = Date()
        if context.isPreview {
            return CalendarEntry(date: now, state: .ready(Sample.engine(now: now)), span: configuration.span)
        }
        let state = DataLoader.load(now: now)
        if case .message = state {
            return CalendarEntry(date: now, state: .ready(Sample.engine(now: now)), span: configuration.span)
        }
        return CalendarEntry(date: now, state: state, span: configuration.span)
    }

    func timeline(for configuration: ShiftCalendarIntent, in context: Context) async -> Timeline<CalendarEntry> {
        let now = Date()
        let state = DataLoader.load(now: now)
        return Timeline(entries: [CalendarEntry(date: now, state: state, span: configuration.span)],
                        policy: .after(nextRefresh(after: now, state: state)))
    }
}

struct ShiftCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ShiftCalendar", intent: ShiftCalendarIntent.self, provider: CalendarProvider()) { entry in
            ShiftCalendarWidgetView(entry: entry).widgetBackground()
        }
        .configurationDisplayName("シフトカレンダー")
        .description("シフトをカレンダーで表示します。長押しして「ウィジェットを編集」で期間を変えられます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

enum CellDensity {
    /// 開始・終了・給与
    case full
    /// 開始・終了
    case compact
    /// 開始だけ
    case mini
    /// 時だけ（例：17〜22）
    case hours
    /// 点だけ
    case dot
}

struct CalendarLayout {
    let rows: [[DayKey]]
    let focusMonth: MonthKey?
    let title: String

    init(span: CalendarSpan, today: DayKey, firstWeekday: Int) {
        func week(from start: DayKey, count: Int) -> [[DayKey]] {
            (0..<count).map { r in (0..<7).map { start.adding(days: r * 7 + $0) } }
        }
        switch span {
        case .weekCentered:
            rows = week(from: today.adding(days: -3), count: 1)
            focusMonth = nil
            title = "今日の前後"
        case .weekFromToday:
            rows = week(from: today, count: 1)
            focusMonth = nil
            title = "今日から1週間"
        case .thisWeek:
            rows = week(from: today.startOfWeek(firstWeekday: firstWeekday), count: 1)
            focusMonth = nil
            title = "今週"
        case .twoWeeks:
            rows = week(from: today.startOfWeek(firstWeekday: firstWeekday), count: 2)
            focusMonth = nil
            title = "2週間"
        case .month:
            rows = today.monthKey.weeks(firstWeekday: firstWeekday)
            focusMonth = today.monthKey
            title = "\(today.month)月"
        }
    }

    var days: [DayKey] {
        let all = rows.flatMap { $0 }
        guard let focusMonth else { return all }
        return all.filter { $0.monthKey == focusMonth }
    }
}

struct ShiftCalendarWidgetView: View {
    let entry: CalendarEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .message(let text):
            MessageView(text: text)
        case .ready(let engine):
            content(engine)
        }
    }

    @ViewBuilder
    private func content(_ engine: PayEngine) -> some View {
        let today = DayKey(entry.date)
        let layout = CalendarLayout(span: entry.span, today: today, firstWeekday: engine.settings.weekStart.rawValue)
        let summary = engine.summary(of: layout.days, now: entry.date)
        VStack(alignment: .leading, spacing: 6) {
            if family == .systemSmall {
                WidgetTitle(text: layout.title, trailing: "\(summary.days)日")
            } else {
                WidgetTitle(text: "\(layout.title)のシフト",
                            trailing: "\(summary.days)日・\(Fmt.hours(summary.paidMinutes))時間・\(Fmt.yen(summary.total))")
            }
            CalendarGrid(rows: layout.rows,
                         focusMonth: layout.focusMonth,
                         today: today,
                         now: entry.date,
                         byDay: engine.byDay,
                         density: density(rows: layout.rows.count))
        }
    }

    private func density(rows: Int) -> CellDensity {
        switch family {
        case .systemSmall:
            return rows == 1 ? .hours : .dot
        case .systemMedium:
            return rows == 1 ? .full : rows == 2 ? .compact : .dot
        default:
            return rows <= 2 ? .full : .mini
        }
    }
}

struct CalendarGrid: View {
    let rows: [[DayKey]]
    let focusMonth: MonthKey?
    let today: DayKey
    let now: Date
    let byDay: [DayKey: [ShiftItem]]
    let density: CellDensity

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                ForEach(rows[0]) { d in
                    Text(Fmt.weekdaySymbol(d.weekday))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(d.weekday == 1 ? Color.red : d.weekday == 7 ? Color.blue : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(rows[r]) { day in
                        WidgetDayCell(day: day,
                                      items: byDay[day] ?? [],
                                      isToday: day == today,
                                      outside: focusMonth.map { day.monthKey != $0 } ?? false,
                                      isPast: day < today,
                                      density: density)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

struct WidgetDayCell: View {
    let day: DayKey
    let items: [ShiftItem]
    let isToday: Bool
    let outside: Bool
    let isPast: Bool
    let density: CellDensity

    private var dateSize: CGFloat {
        switch density {
        case .full: return 13
        case .compact, .hours: return 11
        case .mini, .dot: return 10
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day.day)")
                .font(.system(size: dateSize, weight: isToday ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : numberColor)
                .frame(width: dateSize * 1.75, height: dateSize * 1.6)
                .background {
                    if isToday { Capsule().fill(Color.red) }
                }
            if let item = items.first {
                mark(item)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(outside ? 0.3 : (isPast && !isToday ? 0.55 : 1))
    }

    private var numberColor: Color {
        switch day.weekday {
        case 1: return .red
        case 7: return .blue
        default: return .primary
        }
    }

    @ViewBuilder
    private func mark(_ item: ShiftItem) -> some View {
        switch density {
        case .dot:
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
            Spacer(minLength: 0)
        case .mini:
            Text(Fmt.time(item.start))
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            Spacer(minLength: 0)
        case .hours, .compact, .full:
            VStack(spacing: 1) {
                Text(density == .hours ? Fmt.hour(item.start) : Fmt.time(item.start))
                    .font(.system(size: density == .full ? 12 : 10, weight: .semibold))
                Text("〜" + (density == .hours ? Fmt.hour(item.end) : Fmt.time(item.end)))
                    .font(.system(size: density == .full ? 10 : 9))
                    .foregroundStyle(.secondary)
                if density == .full {
                    Text(Fmt.yen(item.pay.total))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tint)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
