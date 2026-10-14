import SwiftUI
import WidgetKit
import Charts

// ウィジェットの見た目。アプリ内の見本表示（-gallery）でも使うので、サイズは引数で受け取る。

enum CalendarSpanKind: String, CaseIterable {
    case weekCentered, weekFromToday, thisWeek, twoWeeks, month
}

struct WidgetMessageView: View {
    let text: String
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Shift Note：アプリで設定してください")
        case .accessoryRectangular, .accessoryCircular:
            VStack(alignment: .leading) {
                Text("Shift Note").font(.headline)
                Text("アプリで設定してください").font(.caption)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Spacer(minLength: 0)
                Text("Shift Note")
                    .font(.system(size: 15, weight: .heavy).width(.condensed))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct WidgetLabel: View {
    let text: String
    var color: Color = Theme.muted
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(text)
                .font(.system(size: 11, weight: .bold).width(.condensed))
                .tracking(0.8)
                .foregroundStyle(color)
            Spacer(minLength: 2)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold).width(.condensed))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
    }
}

// MARK: - 次のシフト

struct NextShiftWidgetView: View {
    let engine: PayEngine
    let now: Date
    let family: WidgetFamily

    var body: some View {
        let next = engine.next(after: now)
        switch family {
        case .accessoryInline:
            if let next {
                Text("\(Fmt.monthDay(next.start)) \(Fmt.time(next.start))–\(Fmt.time(next.end))")
            } else {
                Text("シフトの予定なし")
            }
        case .accessoryRectangular:
            if let next {
                VStack(alignment: .leading, spacing: 0) {
                    Text(next.start <= now ? "勤務中" : "\(Fmt.dayWithWeekday(next.start)) \(Fmt.relativeDay(next.start, now: now))")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(Fmt.time(next.start))–\(Fmt.time(next.end))")
                        .font(Theme.number(22, weight: .heavy))
                        .widgetAccentable()
                    Text(Fmt.yen(next.pay.total))
                        .font(.system(size: 12, weight: .medium))
                }
                .monospacedDigit()
            } else {
                Text("シフトの予定なし").font(.headline)
            }
        default:
            if let next {
                small(next)
            } else {
                VStack(alignment: .leading) {
                    WidgetLabel(text: "次のシフト")
                    Spacer()
                    Text("予定されたシフトはありません")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func small(_ item: ShiftItem) -> some View {
        let working = item.start <= now
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(item.band.color).frame(width: 7, height: 7)
                WidgetLabel(text: working ? "勤務中" : "次のシフト", color: working ? item.band.color : Theme.muted,
                            trailing: working ? nil : Fmt.relativeDay(item.start, now: now))
            }
            Text(Fmt.dayWithWeekday(item.start))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.weekdayColor(item.workDay.weekday))
                .padding(.top, 2)
            Spacer(minLength: 0)
            Text(Fmt.time(item.start))
                .font(Theme.number(44, weight: .black))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
            Text("– \(Fmt.time(item.end))")
                .font(Theme.number(20, weight: .bold))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            if working {
                ProgressView(timerInterval: item.start...item.end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(item.band.color)
                HStack(spacing: 3) {
                    Text("終わりまで").foregroundStyle(Theme.muted)
                    Text(item.end, style: .timer).foregroundStyle(Theme.ink)
                }
                .font(.system(size: 11, weight: .semibold).width(.condensed))
                .padding(.top, 2)
            } else {
                HStack {
                    Text(Fmt.yen(item.pay.total))
                        .font(Theme.number(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Fmt.hours(item.pay.paidMinutes))h")
                        .font(Theme.number(14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .leading) {
            Capsule().fill(item.band.color).frame(width: 3).padding(.vertical, 2).offset(x: -9)
        }
    }
}

// MARK: - 今月の給与

struct MonthPayWidgetView: View {
    let engine: PayEngine
    let now: Date
    let family: WidgetFamily

    var body: some View {
        let month = MonthKey(now)
        let s = engine.stats(for: month, now: now)
        switch family {
        case .accessoryInline:
            Text("\(month.month)月 \(Fmt.yen(s.total))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text("\(month.month)月の給与").font(.system(size: 12, weight: .semibold))
                Text(Fmt.yen(s.total)).font(Theme.number(22, weight: .heavy)).widgetAccentable()
                Text("\(Fmt.hours(s.paidMinutes))時間 · \(s.days)日").font(.system(size: 12))
            }
            .monospacedDigit()
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetLabel(text: "\(month.month)月の給与 · 控除前")
                    Spacer(minLength: 0)
                    Amount(value: s.total, size: 36)
                    SplitBar(done: s.done, total: s.total, height: 7)
                        .padding(.top, 6)
                    Text("勤務済み \(Fmt.yen(s.done))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .monospacedDigit()
                        .padding(.top, 4)
                }
                Rectangle().fill(Theme.line).frame(width: 0.5)
                VStack(alignment: .leading, spacing: 0) {
                    StatTile(title: "勤務時間", value: Fmt.hours(s.paidMinutes), unit: "時間")
                    Spacer(minLength: 0)
                    StatTile(title: "勤務日数", value: "\(s.days)", unit: "日")
                    Spacer(minLength: 0)
                    StatTile(title: "実質時給", value: s.effectiveHourly.map(Fmt.yen) ?? "—")
                }
                .frame(width: 92)
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                WidgetLabel(text: "\(month.month)月の給与")
                Text("控除前の見込み")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
                Amount(value: s.total, size: 30)
                SplitBar(done: s.done, total: s.total, height: 6)
                    .padding(.top, 6)
                Spacer(minLength: 0)
                HStack {
                    Text("\(Fmt.hours(s.paidMinutes))時間")
                    Spacer()
                    Text("\(s.days)日")
                }
                .font(Theme.number(14, weight: .bold))
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
            }
        }
    }
}

// MARK: - 年収と年収の壁

struct IncomeWidgetView: View {
    let engine: PayEngine
    let now: Date
    let family: WidgetFamily

    var body: some View {
        let year = DayKey(now).year
        let s = engine.yearStats(year, now: now)
        let walls = engine.walls(year: year, now: now)
        let next = walls.statuses.first { !$0.isOver }
        switch family {
        case .accessoryInline:
            Text(next.map { "年収\(Fmt.man(s.total)) · \(Fmt.man($0.wall.amount))まで\(Fmt.man($0.remaining))" } ?? "年収\(Fmt.man(s.total))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(String(year))年 \(Fmt.man(s.total))円").font(.system(size: 14, weight: .bold))
                if let next {
                    Gauge(value: next.progress) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .widgetAccentable()
                    Text("\(Fmt.man(next.wall.amount))まで あと\(Fmt.man(next.remaining))円").font(.system(size: 12))
                } else {
                    Text("178万円を超える見込み").font(.system(size: 12))
                }
            }
            .monospacedDigit()
        case .systemSmall:
            VStack(alignment: .leading, spacing: 0) {
                WidgetLabel(text: "\(String(year))年の年収")
                Spacer(minLength: 0)
                Amount(value: s.total, size: 26)
                WallMeter(value: walls.total, height: 6, showsLabels: false)
                    .padding(.top, 8)
                Spacer(minLength: 0)
                nextWallText(next, compact: true)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetLabel(text: "\(String(year))年の年収見込み")
                    Amount(value: s.total, size: 26)
                        .fixedSize()
                }
                Spacer(minLength: 0)
                WallMeter(value: walls.total, height: 8)
                Spacer(minLength: 0)
                ForEach(walls.statuses.filter { !$0.isOver }.prefix(2)) { w in
                    wallLine(w)
                }
                if next == nil { nextWallText(nil, compact: false) }
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetLabel(text: "\(String(year))年の年収見込み")
                    Amount(value: s.total, size: 28).fixedSize()
                }
                MiniYearChart(months: engine.months(of: year, now: now), current: MonthKey(now), year: year)
                    .frame(maxHeight: .infinity)
                WallMeter(value: walls.total, height: 8)
                VStack(spacing: 5) {
                    ForEach(walls.statuses) { wallLine($0) }
                }
            }
        }
    }

    private func wallLine(_ w: WallStatus) -> some View {
        HStack(spacing: 8) {
            Text(Fmt.man(w.wall.amount))
                .font(Theme.number(14, weight: .heavy))
                .foregroundStyle(w.isOver ? Theme.faint : Theme.ink)
                .frame(width: 44, alignment: .leading)
            Text(w.wall.title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(w.isOver ? "超える見込み" : "あと\(Fmt.man(w.remaining))")
                .font(.system(size: 12, weight: .bold).width(.condensed))
                .foregroundStyle(wallColor(w))
        }
        .monospacedDigit()
    }

    @ViewBuilder
    private func nextWallText(_ next: WallStatus?, compact: Bool) -> some View {
        if let next {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Fmt.man(next.wall.amount))円（\(next.wall.short)）まで")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                Text("あと\(Fmt.man(next.remaining))円")
                    .font(Theme.number(17, weight: .heavy))
                    .foregroundStyle(wallColor(next))
            }
            .monospacedDigit()
        } else {
            Text("178万円を超える見込み")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.negative)
        }
    }

    private func wallColor(_ w: WallStatus) -> Color {
        if w.isOver { return Theme.negative }
        if w.remaining < 100_000 { return Theme.warning }
        return Theme.positive
    }
}

struct MiniYearChart: View {
    let months: [MonthStats]
    let current: MonthKey
    let year: Int

    var body: some View {
        Chart {
            ForEach(Array(months.enumerated()), id: \.offset) { index, s in
                BarMark(x: .value("月", "\(index + 1)"), y: .value("金額", s.done))
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(2)
                BarMark(x: .value("月", "\(index + 1)"), y: .value("金額", s.planned))
                    .foregroundStyle(Theme.accent.opacity(0.3))
                    .cornerRadius(2)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let m = value.as(String.self) {
                        Text(m)
                            .font(.system(size: 8, weight: .semibold).width(.condensed))
                            .foregroundStyle(current.year == year && "\(current.month)" == m ? Theme.ink : Theme.muted)
                    }
                }
            }
        }
    }
}

// MARK: - シフトカレンダー

struct CalendarLayout {
    let rows: [[DayKey]]
    let focusMonth: MonthKey?
    let title: String

    init(span: CalendarSpanKind, today: DayKey, firstWeekday: Int) {
        func weeks(from start: DayKey, count: Int) -> [[DayKey]] {
            (0..<count).map { r in (0..<7).map { start.adding(days: r * 7 + $0) } }
        }
        switch span {
        case .weekCentered:
            rows = weeks(from: today.adding(days: -3), count: 1); focusMonth = nil; title = "今日の前後"
        case .weekFromToday:
            rows = weeks(from: today, count: 1); focusMonth = nil; title = "今日から1週間"
        case .thisWeek:
            rows = weeks(from: today.startOfWeek(firstWeekday: firstWeekday), count: 1); focusMonth = nil; title = "今週"
        case .twoWeeks:
            rows = weeks(from: today.startOfWeek(firstWeekday: firstWeekday), count: 2); focusMonth = nil; title = "2週間"
        case .month:
            rows = today.monthKey.weeks(firstWeekday: firstWeekday); focusMonth = today.monthKey; title = "\(today.month)月"
        }
    }

    var days: [DayKey] {
        let all = rows.flatMap { $0 }
        guard let focusMonth else { return all }
        return all.filter { $0.monthKey == focusMonth }
    }
}

enum CellDensity { case full, compact, mini, hours, dot }

struct CalendarWidgetView: View {
    let engine: PayEngine
    let now: Date
    let family: WidgetFamily
    let span: CalendarSpanKind

    var body: some View {
        let today = DayKey(now)
        let layout = CalendarLayout(span: span, today: today, firstWeekday: engine.settings.weekStart.rawValue)
        let summary = engine.summary(of: layout.days, now: now)
        VStack(alignment: .leading, spacing: 6) {
            if family == .systemSmall {
                WidgetLabel(text: layout.title, trailing: "\(summary.days)日")
            } else {
                WidgetLabel(text: "\(layout.title)のシフト",
                            trailing: "\(summary.days)日 · \(Fmt.hours(summary.paidMinutes))h · \(Fmt.yen(summary.total))")
            }
            WidgetCalendarGrid(rows: layout.rows, focusMonth: layout.focusMonth, today: today,
                               byDay: engine.byDay, density: density(rows: layout.rows.count))
        }
    }

    private func density(rows: Int) -> CellDensity {
        switch family {
        case .systemSmall: return rows == 1 ? .hours : .dot
        case .systemMedium: return rows == 1 ? .full : rows == 2 ? .compact : .dot
        default: return rows <= 2 ? .full : .mini
        }
    }
}

struct WidgetCalendarGrid: View {
    let rows: [[DayKey]]
    let focusMonth: MonthKey?
    let today: DayKey
    let byDay: [DayKey: [ShiftItem]]
    let density: CellDensity

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                ForEach(rows[0]) { d in
                    Text(Fmt.weekdaySymbol(d.weekday))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(d.weekday == 1 ? Theme.sunday : d.weekday == 7 ? Theme.saturday : Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(rows[r]) { day in
                        WidgetDayCell(day: day, item: byDay[day]?.first, isToday: day == today,
                                      outside: focusMonth.map { day.monthKey != $0 } ?? false,
                                      isPast: day < today, density: density)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

struct WidgetDayCell: View {
    let day: DayKey
    let item: ShiftItem?
    let isToday: Bool
    let outside: Bool
    let isPast: Bool
    let density: CellDensity

    private var dateSize: CGFloat {
        switch density {
        case .full: return 14
        case .compact, .hours: return 12
        case .mini, .dot: return 11
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day.day)")
                .font(Theme.number(dateSize, weight: isToday ? .black : .bold))
                .foregroundStyle(isToday ? Theme.paper : numberColor)
                .frame(width: dateSize * 1.7, height: dateSize * 1.55)
                .background { if isToday { Capsule().fill(Theme.ink) } }
            if let item {
                mark(item)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(outside ? 0.28 : (isPast && !isToday ? 0.5 : 1))
    }

    private var numberColor: Color {
        switch day.weekday {
        case 1: return Theme.sunday
        case 7: return Theme.saturday
        default: return Theme.ink
        }
    }

    @ViewBuilder
    private func mark(_ item: ShiftItem) -> some View {
        switch density {
        case .dot:
            Circle().fill(item.band.color).frame(width: 5, height: 5)
            Spacer(minLength: 0)
        case .mini:
            Text(Fmt.time(item.start))
                .font(Theme.number(10, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 14)
                .background(item.band.color, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Spacer(minLength: 0)
        case .hours, .compact, .full:
            VStack(spacing: 1) {
                Text(density == .hours ? Fmt.hour(item.start) : Fmt.time(item.start))
                    .font(Theme.number(density == .full ? 14 : 12, weight: .heavy))
                Text(density == .hours ? Fmt.hour(item.end) : Fmt.time(item.end))
                    .font(Theme.number(density == .full ? 11 : 10, weight: .semibold))
                    .opacity(0.8)
                if density == .full {
                    Text(Fmt.yen(item.pay.total))
                        .font(Theme.number(10, weight: .bold))
                        .opacity(0.9)
                        .padding(.top, 1)
                }
            }
            .foregroundStyle(.white)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(item.band.color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}
