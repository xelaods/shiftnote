import SwiftUI

/// 月のカレンダー。日付をタップすると下にその日のシフトが出る
struct CalendarScreen: View {
    @EnvironmentObject var model: AppModel
    let openDay: (DayKey) -> Void
    @State private var month = MonthKey(Date())
    @State private var selected = DayKey(Date())
    @State private var direction: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header.cinematicReveal(0)
                    if !model.hasAccess {
                        AccessCard()
                    } else {
                        VStack(spacing: 12) {
                            ZStack {
                                MonthGrid(month: month, selected: $selected)
                                    .id(month)
                                    .transition(.cinematicSlide(direction))
                            }
                            .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                                if v.translation.width < -50 { move(1) }
                                if v.translation.width > 50 { move(-1) }
                            })
                            legend
                        }
                        .card(padding: 12)
                        .cinematicReveal(1)

                        selectedDay.cinematicReveal(2)
                        monthTotals.cinematicReveal(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var isCurrentMonth: Bool { month == MonthKey(model.now) }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(month.year))
                    .font(Theme.number(16, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText(value: Double(month.year)))
                Text("\(month.month)")
                    .font(Theme.number(40, weight: .black))
                    .contentTransition(.numericText(value: Double(month.month)))
                    .padding(.leading, 6)
                Text("月")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: 8) {
                Button("今月") {
                    let target = MonthKey(model.now)
                    direction = target > month ? 1 : -1
                    withAnimation(Motion.cinematicFast) {
                        month = target
                        selected = DayKey(model.now)
                    }
                }
                .buttonStyle(GlassCapsuleButtonStyle())
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.35 : 1)
                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(GlassCircleButtonStyle(size: 36))
                    .accessibilityLabel("前の月")
                Button { move(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(GlassCircleButtonStyle(size: 36))
                    .accessibilityLabel("次の月")
            }
        }
    }

    private func move(_ n: Int) {
        direction = CGFloat(n)
        withAnimation(Motion.cinematicFast) {
            month = month.adding(months: n)
            selected = month == MonthKey(model.now) ? DayKey(model.now) : month.firstDay
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(ShiftBand.allCases, id: \.self) { band in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(band.color).frame(width: 10, height: 10)
                    Text(bandRange(band))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bandRange(_ band: ShiftBand) -> String {
        switch band {
        case .morning: return "朝 5–11時"
        case .day: return "昼 11–16時"
        case .evening: return "夕 16–21時"
        case .night: return "夜 21時–"
        }
    }

    private var selectedDay: some View {
        let items = model.engine.items(on: selected)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "\(selected.month)月\(selected.day)日（\(Fmt.weekdaySymbol(selected.weekday))）")
                Spacer()
                if !items.isEmpty {
                    Button("内訳") { openDay(selected) }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            if items.isEmpty {
                Text("シフトはありません")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(items) { item in
                    Button { openDay(selected) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            ShiftRow(item: item, now: model.now, showsDate: false)
                            TimeBar(item: item, height: 18)
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
        .card()
        .animation(Motion.cinematicFast, value: selected)
    }

    private var monthTotals: some View {
        let s = model.engine.stats(for: month, now: model.now)
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "\(month.month)月の合計")
            HStack(alignment: .firstTextBaseline) {
                Amount(value: s.total, size: 34)
                Spacer()
            }
            HStack {
                StatTile(title: "勤務時間", value: Fmt.hours(s.paidMinutes), unit: "時間")
                StatTile(title: "勤務日数", value: "\(s.days)", unit: "日")
                StatTile(title: "深夜", value: Fmt.hours(s.nightMinutes), unit: "時間")
            }
        }
        .card()
    }
}

private struct MonthGrid: View {
    @EnvironmentObject var model: AppModel
    let month: MonthKey
    @Binding var selected: DayKey

    var body: some View {
        let weeks = month.weeks(firstWeekday: model.settings.weekStart.rawValue)
        let byDay = model.engine.byDay
        let today = DayKey(model.now)
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(weeks[0]) { d in
                    Text(Fmt.weekdaySymbol(d.weekday))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(d.weekday == 1 ? Theme.sunday : d.weekday == 7 ? Theme.saturday : Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)
            ForEach(weeks.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(weeks[r]) { day in
                        Cell(day: day,
                             item: byDay[day]?.first,
                             isToday: day == today,
                             isSelected: day == selected,
                             inMonth: day.month == month.month,
                             isPast: day < today)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(Motion.snappy) { selected = day }
                            }
                    }
                }
            }
        }
    }

    private struct Cell: View {
        let day: DayKey
        let item: ShiftItem?
        let isToday: Bool
        let isSelected: Bool
        let inMonth: Bool
        let isPast: Bool

        var body: some View {
            VStack(spacing: 3) {
                Text("\(day.day)")
                    .font(Theme.number(17, weight: isToday || isSelected ? .heavy : .semibold))
                    .foregroundStyle(numberColor)
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(isToday ? Theme.accent : Theme.ink)
                        } else if isToday {
                            Circle().stroke(Theme.accent, lineWidth: 1.5)
                        }
                    }
                if let item {
                    Text(Fmt.time(item.start))
                        .font(Theme.number(11, weight: .heavy))
                        .foregroundStyle(Theme.onBand)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 17)
                        .background(item.band.color.opacity(isPast ? 0.55 : 1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(.horizontal, 3)
                } else {
                    Color.clear.frame(height: 17)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .top)
            .opacity(inMonth ? 1 : 0.3)
            .accessibilityElement(children: .combine)
        }

        private var numberColor: Color {
            if isSelected { return Theme.paper }
            if isToday { return Theme.accent }
            switch day.weekday {
            case 1: return Theme.sunday
            case 7: return Theme.saturday
            default: return Theme.ink
            }
        }
    }
}
