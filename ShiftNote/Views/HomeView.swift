import SwiftUI

/// ホーム：次のシフトを大きく、その下に1週間・今月・今年
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    let openDay: (DayKey) -> Void
    let openIncome: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(eyebrow: todayEyebrow(model.now), title: "Shift Note")
                        .cinematicReveal(0)
                    if !model.hasAccess {
                        AccessCard().cinematicReveal(1)
                    } else {
                        NextShiftHero(openDay: openDay)
                            .cinematicReveal(1)
                        WeekStrip(openDay: openDay)
                            .cinematicReveal(2)
                            .cinematicScroll()
                        MonthCard()
                            .cinematicReveal(3)
                            .cinematicScroll()
                        YearCard(open: openIncome)
                            .cinematicReveal(4)
                            .cinematicScroll()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { model.reload() }
        }
    }
}

// MARK: - 次のシフト

private struct NextShiftHero: View {
    @EnvironmentObject var model: AppModel
    let openDay: (DayKey) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            if let next = model.engine.next(after: now) {
                Button { openDay(next.workDay) } label: { content(next, now: now) }
                    .buttonStyle(PressableCardStyle())
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "次のシフト")
                    Text("予定されたシフトはありません")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("カレンダーに「\(model.settings.eventTitle)」の予定が入ると、ここに表示されます。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .card(padding: 20)
            }
        }
    }

    private func content(_ item: ShiftItem, now: Date) -> some View {
        let working = item.start <= now
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(item.band.color)
                    .frame(width: 8, height: 8)
                    .background {
                        if working {
                            Circle().fill(item.band.color.opacity(0.25)).frame(width: 16, height: 16)
                        }
                    }
                Text(working ? "勤務中" : "次のシフト")
                    .font(Theme.label)
                    .tracking(1.2)
                    .foregroundStyle(working ? item.band.color : Theme.muted)
                Spacer()
                Text("\(Fmt.dayWithWeekday(item.start))・\(Fmt.relativeDay(item.start, now: now))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.time(item.start))
                    .font(Theme.number(64, weight: .black))
                Text("–")
                    .font(Theme.number(34, weight: .bold))
                    .foregroundStyle(Theme.faint)
                Text(Fmt.time(item.end))
                    .font(Theme.number(40, weight: .heavy))
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            if working {
                VStack(alignment: .leading, spacing: 8) {
                    SplitBar(done: item.progress(at: now), total: 1, color: item.band.color, height: 10)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ここまでの給与")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.muted)
                            Amount(value: item.earned(at: now), size: 30, color: item.band.color)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("終わりまで")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.muted)
                            Text(item.end, style: .timer)
                                .font(Theme.number(24, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .monospacedDigit()
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    StatTile(title: "給与", value: Fmt.yen(item.pay.total))
                    StatTile(title: "実働", value: Fmt.hours(item.pay.paidMinutes), unit: "時間")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("開始まで")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.muted)
                        Text(countdown(to: item.start, now: now))
                            .font(Theme.number(22, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(item.band.color)
                .frame(width: 4)
                .padding(.vertical, 6)
        }
        .card(padding: 20)
    }

    /// 2日 4時間 / 3時間12分 / 8分
    private func countdown(to date: Date, now: Date) -> String {
        let minutes = Int(date.timeIntervalSince(now) / 60)
        let d = minutes / 1440, h = minutes % 1440 / 60, m = minutes % 60
        if d > 0 { return "\(d)日\(h)時間" }
        if h > 0 { return "\(h)時間\(m)分" }
        return "\(max(m, 0))分"
    }
}

// MARK: - 1週間（今日を真ん中に）

private struct WeekStrip: View {
    @EnvironmentObject var model: AppModel
    let openDay: (DayKey) -> Void

    var body: some View {
        let today = DayKey(model.now)
        let days = (-3...3).map { today.adding(days: $0) }
        let byDay = model.engine.byDay
        let summary = model.engine.summary(of: days, now: model.now)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "今日の前後")
                Spacer()
                Text("\(summary.days)日 · \(Fmt.hours(summary.paidMinutes))時間 · \(Fmt.yen(summary.total))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
            HStack(spacing: 6) {
                ForEach(days) { day in
                    Button { openDay(day) } label: {
                        DayColumn(day: day, item: byDay[day]?.first, isToday: day == today, isPast: day < today)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
        .card()
    }
}

private struct DayColumn: View {
    let day: DayKey
    let item: ShiftItem?
    let isToday: Bool
    let isPast: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(Fmt.weekdaySymbol(day.weekday))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(day.weekday == 1 ? Theme.sunday : day.weekday == 7 ? Theme.saturday : Theme.muted)
            Text("\(day.day)")
                .font(Theme.number(18, weight: .heavy))
                .foregroundStyle(isToday ? Theme.paper : Theme.ink)
                .frame(width: 30, height: 30)
                .background { if isToday { Circle().fill(Theme.ink) } }
            Group {
                if let item {
                    VStack(spacing: 2) {
                        Text(Fmt.time(item.start))
                            .font(Theme.number(13, weight: .heavy))
                        Text(Fmt.time(item.end))
                            .font(Theme.number(11, weight: .semibold))
                            .opacity(0.75)
                    }
                    .foregroundStyle(Theme.onBand)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(item.band.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text("休")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .opacity(isPast ? 0.5 : 1)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 今月

private struct MonthCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let month = MonthKey(model.now)
        let s = model.engine.stats(for: month, now: model.now)
        let prev = model.engine.stats(for: month.adding(months: -1), now: model.now)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "\(month.month)月の給与 · 控除前")
                Spacer()
                if prev.total > 0 {
                    let diff = s.total - prev.total
                    Label(Fmt.signedYen(diff), systemImage: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(diff >= 0 ? Theme.positive : Theme.negative)
                        .monospacedDigit()
                }
            }
            Amount(value: s.total, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                SplitBar(done: s.done, total: s.total, height: 10)
                HStack {
                    legend(Theme.accent, "勤務済み", s.done)
                    Spacer()
                    legend(Theme.accent.opacity(0.3), "これから", s.planned)
                }
            }
            Divider().overlay(Theme.line)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 14) {
                GridRow {
                    StatTile(title: "勤務時間", value: Fmt.hours(s.paidMinutes), unit: "時間")
                    StatTile(title: "勤務日数", value: "\(s.days)", unit: "日")
                    StatTile(title: "実質時給", value: s.effectiveHourly.map(Fmt.yen) ?? "—")
                }
                GridRow {
                    StatTile(title: "基本給", value: Fmt.yen(s.base))
                    StatTile(title: "深夜手当", value: Fmt.yen(s.night))
                    StatTile(title: "交通費", value: Fmt.yen(s.transport))
                }
            }
        }
        .card(padding: 20)
    }

    private func legend(_ color: Color, _ title: String, _ value: Double) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(title) \(Fmt.yen(value))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
        }
    }
}

// MARK: - 今年

private struct YearCard: View {
    @EnvironmentObject var model: AppModel
    let open: () -> Void

    var body: some View {
        let year = DayKey(model.now).year
        let s = model.engine.yearStats(year, now: model.now)
        let walls = model.engine.walls(year: year, now: model.now)
        let next = walls.statuses.first { !$0.isOver }
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "\(String(year))年の年収見込み")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.faint)
                }
                Amount(value: s.total, size: 34)
                WallMeter(value: walls.total)
                if let next {
                    HStack(spacing: 6) {
                        Text("\(Fmt.man(next.wall.amount))円（\(next.wall.short)）まで")
                            .foregroundStyle(Theme.muted)
                        Text("あと\(Fmt.man(next.remaining))円")
                            .foregroundStyle(next.remaining < 100_000 ? Theme.warning : Theme.ink)
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                } else {
                    Text("178万円（所得税）を超える見込みです")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.negative)
                }
            }
            .card(padding: 20)
        }
        .buttonStyle(PressableCardStyle())
    }
}
