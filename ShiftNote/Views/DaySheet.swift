import SwiftUI

/// 1日のシフトと給与の内訳
struct DaySheet: View {
    @EnvironmentObject var model: AppModel
    let day: DayKey

    var body: some View {
        let items = model.engine.items(on: day)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(day.month)/\(day.day)")
                        .font(Theme.number(40, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("\(Fmt.weekdaySymbol(day.weekday))曜日")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.weekdayColor(day.weekday))
                    Spacer()
                    Text(Fmt.relativeDay(day.date, now: model.now))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 8)

                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("シフトはありません")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("この日は休みです。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .card(padding: 20)
                }

                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ShiftChip(item: item)
                            Spacer()
                            Amount(value: item.pay.total, size: 30)
                        }
                        TimeBar(item: item)
                        VStack(spacing: 10) {
                            row("基本給", "実働\(Fmt.hours(item.pay.paidMinutes))時間", item.pay.base)
                            if item.pay.night > 0 {
                                row("深夜手当", "\(Fmt.hours(item.pay.nightMinutes))時間 × \(Int(model.settings.rates.nightPremium))%", item.pay.night)
                            }
                            if item.pay.transport > 0 {
                                row("交通費", "1回分", item.pay.transport)
                            }
                            if item.pay.restMinutes > 0 {
                                HStack {
                                    Text("休憩")
                                    Spacer()
                                    Text("\(Int(item.pay.restMinutes))分（勤務時間から差し引き）")
                                        .foregroundStyle(Theme.muted)
                                }
                                .font(.system(size: 14))
                            }
                            Divider().overlay(Theme.line)
                            HStack {
                                Text("合計（控除前）")
                                    .font(.system(size: 15, weight: .bold))
                                Spacer()
                                Text(Fmt.yen(item.pay.total))
                                    .font(Theme.number(22, weight: .heavy))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(Theme.ink)
                    }
                    .card(padding: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.paper)
    }

    private func row(_ title: String, _ detail: String, _ value: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(Fmt.yen(value))
                .font(Theme.number(17, weight: .bold))
                .monospacedDigit()
        }
        .font(.system(size: 14))
    }
}
