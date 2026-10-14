import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                SetupSection()
                if model.hasAccess && !model.needsCalendar {
                    NextShiftSection()
                    ThisMonthSection()
                    UpcomingSection()
                    YearSummarySection()
                }
            }
            .navigationTitle("Shift Note")
            .refreshable { model.reload() }
        }
    }
}

private struct NextShiftSection: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Section("次のシフト") {
            if let next = model.engine.next(after: model.now) {
                let working = next.start <= model.now
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Fmt.dayWithWeekday(next.start))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(weekdayColor(next.workDay.weekday))
                        Text(working ? "勤務中" : Fmt.relativeDay(next.start, now: model.now))
                            .font(.subheadline)
                            .foregroundStyle(working ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        Spacer()
                        Text(Fmt.yen(next.pay.total))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                    Text("\(Fmt.time(next.start))〜\(Fmt.time(next.end))")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("実働\(Fmt.hours(next.pay.paidMinutes))時間" + (next.pay.restMinutes > 0 ? "・休憩\(Int(next.pay.restMinutes))分" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                Text("予定されているシフトはありません")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThisMonthSection: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let month = MonthKey(model.now)
        let stats = model.engine.stats(for: month, now: model.now)
        let previous = model.engine.stats(for: month.adding(months: -1), now: model.now)
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("予想給与（控除前）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                AmountText(value: stats.total, size: 40)
                ProgressView(value: stats.progress)
                HStack {
                    Text("勤務済み \(Fmt.yen(stats.done))")
                    Spacer()
                    Text("これから \(Fmt.yen(stats.planned))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .padding(.vertical, 6)
            LabeledContent("勤務時間", value: "\(Fmt.hours(stats.paidMinutes))時間")
            LabeledContent("勤務日数", value: "\(stats.days)日")
            LabeledContent("実質時給", value: stats.effectiveHourly.map(Fmt.yen) ?? "—")
            LabeledContent("深夜手当", value: Fmt.yen(stats.night))
            LabeledContent("交通費", value: Fmt.yen(stats.transport))
            if previous.total > 0 {
                LabeledContent("前月比") {
                    Text(Fmt.signedYen(stats.total - previous.total))
                        .foregroundStyle(stats.total >= previous.total ? .green : .red)
                }
            }
        } header: {
            Text("\(month.month)月")
        }
        .monospacedDigit()
    }
}

private struct UpcomingSection: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let items = model.engine.upcoming(after: model.now, limit: 6).dropFirst()
        if !items.isEmpty {
            Section("これからのシフト") {
                ForEach(Array(items)) { item in
                    ShiftRow(item: item, now: model.now)
                }
            }
        }
    }
}

private struct YearSummarySection: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("selectedTab") private var tab = 0

    var body: some View {
        let year = DayKey(model.now).year
        let stats = model.engine.yearStats(year, now: model.now)
        let walls = model.engine.walls(year: year, now: model.now)
        Section("\(String(year))年") {
            LabeledContent("年収の見込み", value: Fmt.yen(stats.total))
            if let next = walls.statuses.first(where: { !$0.isOver }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(Fmt.man(next.wall.amount))円（\(next.wall.short)）まで")
                        Spacer()
                        Text("あと\(Fmt.man(next.remaining))円")
                            .foregroundStyle(next.remaining < 100_000 ? .orange : .secondary)
                    }
                    ProgressView(value: next.progress)
                        .tint(next.remaining < 100_000 ? .orange : .accentColor)
                }
                .padding(.vertical, 2)
            }
            Button("年収の詳細") { tab = 2 }
        }
        .monospacedDigit()
    }
}
