import SwiftUI

/// 純正カレンダーのような月表示
struct ShiftCalendarScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var month = MonthKey(Date())
    @State private var selected = DayKey(Date())

    var body: some View {
        NavigationStack {
            List {
                SetupSection()
                Section {
                    MonthGrid(month: month, selected: $selected)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                            if value.translation.width < -40 { move(1) }
                            if value.translation.width > 40 { move(-1) }
                        })
                }
                Section(Fmt.dayWithWeekday(selected.date)) {
                    let items = model.engine.items(on: selected)
                    if items.isEmpty {
                        Text("シフトはありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            ShiftRow(item: item, now: model.now, showsDate: false)
                        }
                    }
                }
                let stats = model.engine.stats(for: month, now: model.now)
                Section("\(month.month)月の合計") {
                    LabeledContent("給与（控除前）", value: Fmt.yen(stats.total))
                    LabeledContent("勤務時間", value: "\(Fmt.hours(stats.paidMinutes))時間")
                    LabeledContent("勤務日数", value: "\(stats.days)日")
                }
                .monospacedDigit()
            }
            .navigationTitle("\(String(month.year))年\(month.month)月")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("今日") {
                        withAnimation {
                            month = MonthKey(model.now)
                            selected = DayKey(model.now)
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { move(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("前の月")
                    Button { move(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("次の月")
                }
            }
        }
    }

    private func move(_ n: Int) {
        withAnimation(.snappy) {
            month = month.adding(months: n)
            selected = month == MonthKey(model.now) ? DayKey(model.now) : month.firstDay
        }
    }
}

private struct MonthGrid: View {
    @EnvironmentObject var model: AppModel
    let month: MonthKey
    @Binding var selected: DayKey

    var body: some View {
        let firstWeekday = model.settings.weekStart.rawValue
        let weeks = month.weeks(firstWeekday: firstWeekday)
        let byDay = model.engine.byDay
        let today = DayKey(model.now)
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(weeks[0]) { d in
                    Text(Fmt.weekdaySymbol(d.weekday))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(d.weekday == 1 ? Color.red : d.weekday == 7 ? Color.blue : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(weeks[r]) { day in
                        DayCell(day: day,
                                item: byDay[day]?.first,
                                isToday: day == today,
                                isSelected: day == selected,
                                inMonth: day.month == month.month,
                                isPast: day < today)
                            .contentShape(Rectangle())
                            .onTapGesture { selected = day }
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: DayKey
    let item: ShiftItem?
    let isToday: Bool
    let isSelected: Bool
    let inMonth: Bool
    let isPast: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text("\(day.day)")
                .font(.callout.weight(isToday || isSelected ? .semibold : .regular))
                .foregroundStyle(numberColor)
                .frame(width: 30, height: 30)
                .background {
                    if isSelected {
                        Circle().fill(isToday ? Color.red : Color.primary)
                    }
                }
            if let item {
                Text(Fmt.time(item.start))
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(isPast ? 0.12 : 0.2), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(isPast ? Color.secondary : Color.primary)
                    .padding(.horizontal, 2)
            } else {
                Color.clear.frame(height: 17)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .top)
        .opacity(inMonth ? 1 : 0.35)
        .accessibilityElement(children: .combine)
    }

    private var numberColor: Color {
        if isSelected { return isToday ? .white : Color(uiColor: .systemBackground) }
        if isToday { return .red }
        switch day.weekday {
        case 1: return .red
        case 7: return .blue
        default: return .primary
        }
    }
}
