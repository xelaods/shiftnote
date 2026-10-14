import SwiftUI
import Charts

struct IncomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var year = DayKey(Date()).year
    @AppStorage("basis") private var basisRaw = Basis.work.rawValue

    private var basis: Basis { Basis(rawValue: basisRaw) ?? .work }

    var body: some View {
        NavigationStack {
            List {
                SetupSection()
                let months = model.engine.months(of: year, basis: basis, now: model.now)
                let stats = model.engine.yearStats(year, basis: basis, now: model.now)
                Section {
                    Picker("集計", selection: $basisRaw) {
                        ForEach(Basis.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("年収の見込み（控除前）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        AmountText(value: stats.total, size: 40)
                        Text("勤務済み \(Fmt.yen(stats.done))・これから \(Fmt.yen(stats.planned))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    MonthlyChart(months: months, year: year, now: model.now)
                        .frame(height: 190)
                        .padding(.vertical, 6)
                }

                WallsSection(year: year)

                Section("月別") {
                    ForEach(1...12, id: \.self) { m in
                        let s = months[m - 1]
                        NavigationLink {
                            MonthDetailView(month: MonthKey(year: year, month: m), basis: basis)
                        } label: {
                            HStack {
                                Text("\(m)月")
                                Spacer()
                                if s.paidMinutes > 0 {
                                    Text("\(Fmt.hours(s.paidMinutes))時間")
                                        .foregroundStyle(.secondary)
                                }
                                Text(Fmt.yen(s.total))
                                    .frame(minWidth: 90, alignment: .trailing)
                            }
                            .monospacedDigit()
                        }
                        .disabled(s.shiftCount == 0)
                    }
                }

                Section("内訳") {
                    LabeledContent("月平均", value: model.engine.monthlyAverage(year: year, basis: basis, now: model.now).map(Fmt.yen) ?? "—")
                    LabeledContent("勤務時間", value: "\(Fmt.hours(stats.paidMinutes))時間")
                    LabeledContent("勤務日数", value: "\(stats.days)日")
                    LabeledContent("基本給", value: Fmt.yen(stats.base))
                    LabeledContent("深夜手当", value: Fmt.yen(stats.night))
                    LabeledContent("交通費", value: Fmt.yen(stats.transport))
                }
                .monospacedDigit()
            }
            .navigationTitle("年収")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("年", selection: $year) {
                            ForEach(model.engine.years, id: \.self) { Text(verbatim: "\($0)年").tag($0) }
                        }
                    } label: {
                        Label(String(year) + "年", systemImage: "calendar")
                            .labelStyle(.titleOnly)
                    }
                }
            }
        }
    }
}

private struct MonthlyChart: View {
    let months: [MonthStats]
    let year: Int
    let now: Date

    var body: some View {
        let current = MonthKey(now)
        Chart {
            ForEach(Array(months.enumerated()), id: \.offset) { index, s in
                BarMark(x: .value("月", "\(index + 1)"), y: .value("金額", s.done))
                    .foregroundStyle(by: .value("状態", "勤務済み"))
                BarMark(x: .value("月", "\(index + 1)"), y: .value("金額", s.planned))
                    .foregroundStyle(by: .value("状態", "これから"))
            }
            if current.year == year {
                RuleMark(x: .value("月", "\(current.month)"))
                    .foregroundStyle(.secondary.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 18))
                    .zIndex(-1)
            }
        }
        .chartForegroundStyleScale(["勤務済み": Color.accentColor, "これから": Color.accentColor.opacity(0.35)])
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(Fmt.man(v)) }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
    }
}

private struct WallsSection: View {
    @EnvironmentObject var model: AppModel
    let year: Int

    var body: some View {
        let walls = model.engine.walls(year: year, now: model.now)
        Section {
            LabeledContent("給料日の月で集計", value: Fmt.yen(walls.total))
                .monospacedDigit()
            ForEach(walls.statuses) { s in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.man(s.wall.amount) + "円")
                            .font(.headline)
                            .monospacedDigit()
                        Text(s.wall.title)
                            .font(.subheadline)
                        Spacer()
                        Text(s.isOver ? "超える見込み" : "あと\(Fmt.man(s.remaining))円")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(color(s))
                            .monospacedDigit()
                    }
                    ProgressView(value: s.progress)
                        .tint(color(s))
                    Text(s.wall.who + (s.wall.includesTransport ? "・交通費込み" : "・交通費を除く"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("年収の壁")
        } footer: {
            Text("2026年分の目安です。税金と親の控除は1〜12月に支払われた給与（通勤手当を除く）で決まります。社会保険の扶養は、これから1年の見込み収入（交通費込み）で判断されます。最終的な判断は勤務先に確認してください。")
        }
    }

    private func color(_ s: WallStatus) -> Color {
        if s.isOver { return .red }
        if s.remaining < 100_000 { return .orange }
        return .accentColor
    }
}

struct MonthDetailView: View {
    @EnvironmentObject var model: AppModel
    let month: MonthKey
    let basis: Basis

    var body: some View {
        let items = model.engine.items(in: month, basis: basis)
        let stats = MonthStats(items: items, now: model.now)
        List {
            Section {
                LabeledContent("給与（控除前）", value: Fmt.yen(stats.total))
                LabeledContent("勤務時間", value: "\(Fmt.hours(stats.paidMinutes))時間")
                LabeledContent("勤務日数", value: "\(stats.days)日")
                LabeledContent("実質時給", value: stats.effectiveHourly.map(Fmt.yen) ?? "—")
                LabeledContent("深夜手当", value: Fmt.yen(stats.night))
                LabeledContent("交通費", value: Fmt.yen(stats.transport))
            } footer: {
                Text(basis == .work ? "\(month.month)月に働いた分" : "\(month.month)月に支払われる分")
            }
            .monospacedDigit()
            Section("シフト") {
                ForEach(items) { ShiftRow(item: $0, now: model.now) }
            }
        }
        .navigationTitle("\(String(month.year))年\(month.month)月")
        .navigationBarTitleDisplayMode(.inline)
    }
}
