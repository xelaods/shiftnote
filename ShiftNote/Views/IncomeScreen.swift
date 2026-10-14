import SwiftUI
import Charts

/// 年収：見込み・月別グラフ・年収の壁・月ごとの明細
struct IncomeScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var year = DayKey(Date()).year
    @State private var direction: CGFloat = 1
    @AppStorage("basis") private var basisRaw = Basis.work.rawValue

    private var basis: Basis { Basis(rawValue: basisRaw) ?? .work }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header.cinematicReveal(0)
                    if !model.hasAccess {
                        AccessCard()
                    } else {
                        Group {
                            YearHero(year: year, basis: basis, basisRaw: $basisRaw)
                                .cinematicReveal(1)
                            WallsCard(year: year)
                                .cinematicReveal(2)
                                .cinematicScroll()
                            MonthsList(year: year, basis: basis)
                                .cinematicReveal(3)
                                .cinematicScroll()
                            BreakdownCard(year: year, basis: basis)
                                .cinematicScroll()
                        }
                        .id(year)
                        .transition(.cinematicSlide(direction))
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

    private var header: some View {
        let years = model.engine.years
        return ScreenHeader(eyebrow: "控除前の見込み", title: "\(String(year))年") {
            HStack(spacing: 8) {
                Button { change(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(GlassCircleButtonStyle(size: 36))
                    .disabled(year <= (years.first ?? year))
                    .opacity(year <= (years.first ?? year) ? 0.35 : 1)
                Button { change(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(GlassCircleButtonStyle(size: 36))
                    .disabled(year >= (years.last ?? year))
                    .opacity(year >= (years.last ?? year) ? 0.35 : 1)
            }
        }
    }

    private func change(_ n: Int) {
        direction = CGFloat(n)
        withAnimation(Motion.cinematicFast) { year += n }
    }
}

private struct YearHero: View {
    @EnvironmentObject var model: AppModel
    let year: Int
    let basis: Basis
    @Binding var basisRaw: String
    @State private var selectedMonth: String?

    var body: some View {
        let months = model.engine.months(of: year, basis: basis, now: model.now)
        let s = model.engine.yearStats(year, basis: basis, now: model.now)
        let selectedIndex = selectedMonth.flatMap { Int($0) }.map { $0 - 1 }
        VStack(alignment: .leading, spacing: 14) {
            BasisPicker(selection: $basisRaw)
            VStack(alignment: .leading, spacing: 2) {
                if let i = selectedIndex, months.indices.contains(i) {
                    SectionLabel(text: "\(i + 1)月")
                    Amount(value: months[i].total, size: 48)
                    Text("\(Fmt.hours(months[i].paidMinutes))時間 · \(months[i].days)日")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                } else {
                    SectionLabel(text: "年収の見込み")
                    Amount(value: s.total, size: 48)
                    Text("勤務済み \(Fmt.yen(s.done)) · これから \(Fmt.yen(s.planned))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .monospacedDigit()
                }
            }
            .animation(Motion.snappy, value: selectedMonth)

            Chart {
                ForEach(Array(months.enumerated()), id: \.offset) { index, m in
                    let label = "\(index + 1)"
                    let dim = selectedMonth != nil && selectedMonth != label
                    BarMark(x: .value("月", label), y: .value("金額", m.done))
                        .foregroundStyle(Theme.accent.opacity(dim ? 0.35 : 1))
                        .cornerRadius(3)
                    BarMark(x: .value("月", label), y: .value("金額", m.planned))
                        .foregroundStyle(Theme.accent.opacity(dim ? 0.12 : 0.32))
                        .cornerRadius(3)
                }
                if let avg = model.engine.monthlyAverage(year: year, basis: basis, now: model.now) {
                    RuleMark(y: .value("平均", avg))
                        .foregroundStyle(Theme.muted.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("月平均 \(Fmt.man(avg))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.muted)
                        }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.line)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.man(v)).font(.system(size: 10).width(.condensed)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let m = value.as(String.self) {
                            Text(m).font(.system(size: 10, weight: .semibold).width(.condensed))
                                .foregroundStyle(isCurrent(m) ? Theme.ink : Theme.muted)
                        }
                    }
                }
            }
            .frame(height: 180)
            Text("グラフを押さえたまま動かすと、月ごとの金額が見られます。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
        }
        .card(padding: 20)
        .sensoryFeedback(.selection, trigger: selectedMonth)
    }

    private func isCurrent(_ m: String) -> Bool {
        let c = MonthKey(model.now)
        return c.year == year && "\(c.month)" == m
    }
}

private struct BasisPicker: View {
    @Binding var selection: String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Basis.allCases) { b in
                Button {
                    withAnimation(Motion.snappy) { selection = b.rawValue }
                } label: {
                    Text(b == .work ? "働いた月で集計" : "給料日の月で集計")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == b.rawValue ? Theme.paper : Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selection == b.rawValue {
                                Capsule().fill(Theme.ink).matchedGeometryEffect(id: "basis", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.fill, in: Capsule())
    }
}

private struct WallsCard: View {
    @EnvironmentObject var model: AppModel
    let year: Int
    @State private var expanded = false

    var body: some View {
        let walls = model.engine.walls(year: year, now: model.now)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "年収の壁 · 給料日の月で集計")
                Spacer()
                Text(Fmt.yen(walls.total))
                    .font(Theme.number(17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }
            WallMeter(value: walls.total, height: 10)
            VStack(spacing: 0) {
                ForEach(walls.statuses) { s in
                    WallRow(status: s)
                    if s.id != walls.statuses.last?.id { Divider().overlay(Theme.line) }
                }
            }
            DisclosureGroup(isExpanded: $expanded) {
                Text("2026年分の目安です。所得税・住民税・親の控除は、1〜12月に支払われた給与（通勤手当を除く）で決まります。社会保険の扶養は、これから1年の見込み収入（交通費込み）で判断されます。最終的な判断は勤務先に確認してください。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)
            } label: {
                Text("年収の壁について")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.muted)
        }
        .card(padding: 20)
    }
}

private struct WallRow: View {
    let status: WallStatus

    var body: some View {
        HStack(spacing: 12) {
            Text(Fmt.man(status.wall.amount))
                .font(Theme.number(20, weight: .heavy))
                .foregroundStyle(status.isOver ? Theme.faint : Theme.ink)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.wall.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(status.wall.who + (status.wall.includesTransport ? "・交通費込み" : "・交通費を除く"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Text(status.isOver ? "超える見込み" : "あと\(Fmt.man(status.remaining))")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }

    private var color: Color {
        if status.isOver { return Theme.negative }
        if status.remaining < 100_000 { return Theme.warning }
        return Theme.positive
    }
}

private struct MonthsList: View {
    @EnvironmentObject var model: AppModel
    let year: Int
    let basis: Basis

    var body: some View {
        let months = model.engine.months(of: year, basis: basis, now: model.now)
        let maxTotal = max(months.map(\.total).max() ?? 1, 1)
        let current = MonthKey(model.now)
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "月ごと")
                .padding(.bottom, 8)
            ForEach(1...12, id: \.self) { m in
                let s = months[m - 1]
                NavigationLink {
                    MonthDetailView(month: MonthKey(year: year, month: m), basis: basis)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(m)月")
                            .font(Theme.number(17, weight: .bold))
                            .foregroundStyle(current == MonthKey(year: year, month: m) ? Theme.accent : Theme.ink)
                            .frame(width: 40, alignment: .leading)
                        GeometryReader { g in
                            SplitBar(done: s.done, total: s.total, height: 6)
                                .frame(width: max(6, g.size.width * s.total / maxTotal))
                                .opacity(s.total > 0 ? 1 : 0)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(height: 20)
                        Text(s.total > 0 ? Fmt.yen(s.total) : "—")
                            .font(Theme.number(16, weight: .bold))
                            .foregroundStyle(s.total > 0 ? Theme.ink : Theme.faint)
                            .monospacedDigit()
                            .frame(width: 88, alignment: .trailing)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.faint)
                            .opacity(s.shiftCount > 0 ? 1 : 0)
                    }
                    .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                .disabled(s.shiftCount == 0)
            }
        }
        .card(padding: 20)
    }
}

private struct BreakdownCard: View {
    @EnvironmentObject var model: AppModel
    let year: Int
    let basis: Basis

    var body: some View {
        let s = model.engine.yearStats(year, basis: basis, now: model.now)
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "内訳")
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 14) {
                GridRow {
                    StatTile(title: "勤務時間", value: Fmt.hours(s.paidMinutes), unit: "時間")
                    StatTile(title: "勤務日数", value: "\(s.days)", unit: "日")
                    StatTile(title: "実質時給", value: s.effectiveHourly.map(Fmt.yen) ?? "—")
                }
                GridRow {
                    StatTile(title: "基本給", value: Fmt.man(s.base), unit: "円")
                    StatTile(title: "深夜手当", value: Fmt.yen(s.night))
                    StatTile(title: "交通費", value: Fmt.yen(s.transport))
                }
            }
        }
        .card(padding: 20)
    }
}

struct MonthDetailView: View {
    @EnvironmentObject var model: AppModel
    let month: MonthKey
    let basis: Basis
    @State private var sheetDay: DayKey?

    var body: some View {
        let items = model.engine.items(in: month, basis: basis)
        let s = MonthStats(items: items, now: model.now)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: basis == .work ? "\(month.month)月に働いた分" : "\(month.month)月に支払われる分")
                    Amount(value: s.total, size: 44)
                    SplitBar(done: s.done, total: s.total, height: 8)
                    HStack {
                        StatTile(title: "勤務時間", value: Fmt.hours(s.paidMinutes), unit: "時間")
                        StatTile(title: "勤務日数", value: "\(s.days)", unit: "日")
                        StatTile(title: "実質時給", value: s.effectiveHourly.map(Fmt.yen) ?? "—")
                    }
                }
                .card(padding: 20)
                .cinematicReveal(0)

                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Button { sheetDay = item.workDay } label: {
                            ShiftRow(item: item, now: model.now)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if item.id != items.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .card(padding: 14)
                .cinematicReveal(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.paper)
        .navigationTitle("\(String(month.year))年\(month.month)月")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheetDay) { day in
            DaySheet(day: day)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
