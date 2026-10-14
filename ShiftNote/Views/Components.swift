import SwiftUI
import UIKit

/// カレンダーの許可・選択がまだのときの案内
struct SetupSection: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if !model.hasAccess {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("カレンダーへのアクセス", systemImage: "calendar.badge.exclamationmark")
                        .font(.headline)
                    Text("iPhoneのカレンダーにある「\(model.settings.eventTitle)」の予定から、給与と勤務時間を計算します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if ShiftRepository.accessDenied {
                    Button("設定アプリで許可する") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else {
                    Button("アクセスを許可") {
                        Task { await model.requestAccess() }
                    }
                }
            }
        } else if model.needsCalendar {
            Section {
                Picker("シフトのカレンダー", selection: $model.settings.calendarIdentifier) {
                    Text("選択してください").tag(String?.none)
                    ForEach(model.calendars, id: \.calendarIdentifier) { c in
                        Text(c.title).tag(Optional(c.calendarIdentifier))
                    }
                }
            } footer: {
                Text("「\(model.settings.eventTitle)」の予定が入っているカレンダーを選んでください。")
            }
        }
    }
}

/// 金額の大きな表示
struct AmountText: View {
    let value: Double
    var size: CGFloat = 34

    var body: some View {
        Text(Fmt.yen(value))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

/// 1シフトの行
struct ShiftRow: View {
    let item: ShiftItem
    let now: Date
    var showsDate = true

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if showsDate {
                    HStack(spacing: 6) {
                        Text(Fmt.dayWithWeekday(item.start))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(weekdayColor(item.workDay.weekday))
                        if item.start <= now && item.end > now {
                            Text("勤務中").font(.caption.weight(.semibold)).foregroundStyle(.tint)
                        }
                    }
                }
                Text("\(Fmt.time(item.start))〜\(Fmt.time(item.end))")
                    .font(showsDate ? .body : .headline)
                    .monospacedDigit()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Fmt.yen(item.pay.total))
                .font(.body.weight(.medium))
                .monospacedDigit()
        }
        .opacity(item.end <= now ? 0.6 : 1)
    }

    private var detail: String {
        var parts = ["実働\(Fmt.hours(item.pay.paidMinutes))時間"]
        if item.pay.restMinutes > 0 { parts.append("休憩\(Int(item.pay.restMinutes))分") }
        if item.pay.nightMinutes > 0 { parts.append("深夜\(Fmt.hours(item.pay.nightMinutes))時間") }
        return parts.joined(separator: "・")
    }
}

func weekdayColor(_ weekday: Int) -> Color {
    switch weekday {
    case 1: return .red
    case 7: return .blue
    default: return .primary
    }
}
