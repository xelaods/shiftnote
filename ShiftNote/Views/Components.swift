import SwiftUI
import UIKit

/// シフトの時間帯の色の帯（カレンダーや一覧で使う）
struct ShiftChip: View {
    let item: ShiftItem
    var past = false

    var body: some View {
        HStack(spacing: 6) {
            Text(item.band.label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(item.band.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("\(Fmt.time(item.start))–\(Fmt.time(item.end))")
                .font(Theme.number(17, weight: .bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .opacity(past ? 0.55 : 1)
    }
}

/// 0時〜24時の帯に、シフトの時間と深夜（22時〜5時）を描く
struct TimeBar: View {
    let item: ShiftItem
    var height: CGFloat = 26

    var body: some View {
        let day = item.workDay.date
        let startH = item.start.timeIntervalSince(day) / 3600
        let endH = item.end.timeIntervalSince(day) / 3600
        let maxH = max(24, ceil(endH))
        VStack(spacing: 4) {
            GeometryReader { g in
                let w = g.size.width
                let x = { (h: Double) -> CGFloat in CGFloat(h / maxH) * w }
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.fill)
                    // 深夜の時間帯（0〜5時、22〜29時）
                    ForEach(0..<2, id: \.self) { i in
                        let s = min(i == 0 ? 0.0 : 22.0, maxH), e = min(i == 0 ? 5.0 : 29.0, maxH)
                        if e > s {
                            Rectangle()
                                .fill(ShiftBand.night.color.opacity(0.12))
                                .frame(width: x(e) - x(s))
                                .offset(x: x(s))
                        }
                    }
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(item.band.color)
                        .frame(width: max(4, x(endH) - x(startH)), height: height - 8)
                        .offset(x: x(startH))
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(height: height)
            HStack {
                ForEach(Array(stride(from: 0, through: Int(maxH), by: 6)), id: \.self) { h in
                    Text("\(h % 24)")
                        .font(.system(size: 10, weight: .semibold).width(.condensed))
                        .foregroundStyle(Theme.faint)
                    if h + 6 <= Int(maxH) { Spacer(minLength: 0) }
                }
            }
        }
    }
}

/// シフト1件の行
struct ShiftRow: View {
    let item: ShiftItem
    let now: Date
    var showsDate = true

    var body: some View {
        HStack(spacing: 12) {
            if showsDate {
                VStack(spacing: 0) {
                    Text("\(item.workDay.day)")
                        .font(Theme.number(24, weight: .black))
                        .foregroundStyle(Theme.weekdayColor(item.workDay.weekday))
                    Text(Fmt.weekdaySymbol(item.workDay.weekday))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(width: 34)
            }
            VStack(alignment: .leading, spacing: 3) {
                ShiftChip(item: item)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
            Text(Fmt.yen(item.pay.total))
                .font(Theme.number(19, weight: .bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .opacity(item.end <= now ? 0.55 : 1)
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts = ["実働\(Fmt.hours(item.pay.paidMinutes))時間"]
        if item.pay.restMinutes > 0 { parts.append("休憩\(Int(item.pay.restMinutes))分") }
        if item.pay.nightMinutes > 0 { parts.append("深夜\(Fmt.hours(item.pay.nightMinutes))時間") }
        if item.start <= now && item.end > now { parts.insert("勤務中", at: 0) }
        return parts.joined(separator: " · ")
    }
}

/// カレンダーの許可がないときの案内
struct AccessCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("カレンダーへのアクセスが必要です")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("カレンダーにある「\(model.settings.eventTitle)」の予定から、給与と勤務時間を計算します。")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Button(ShiftRepository.accessDenied ? "設定アプリで許可する" : "アクセスを許可") {
                if ShiftRepository.accessDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } else {
                    Task { await model.requestAccess() }
                }
            }
            .buttonStyle(GlassPrimaryButtonStyle(tint: Theme.accent))
            .padding(.top, 4)
        }
        .card(padding: 20)
    }
}

/// 画面の見出し（日付＋大きなタイトル＋右側のボタン）
struct ScreenHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text(title)
                    .font(.system(size: 32, weight: .heavy).width(.condensed))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}

/// 今日の日付（10月14日 水曜日）
func todayEyebrow(_ now: Date) -> String {
    let d = DayKey(now)
    return "\(d.month)月\(d.day)日 \(Fmt.weekdaySymbol(d.weekday))曜日"
}
