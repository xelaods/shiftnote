import SwiftUI
import UIKit

/// 1日の希望を変える（シフコンの「マス」を押したときのポップアップにあたる）
struct RequestEditor: View {
    @EnvironmentObject var client: ShifconClient
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let day: RequestDay

    @State private var isWork: Bool
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var wantsContact: Bool
    @State private var holidayType: String
    @State private var reason: String
    @State private var error: String?

    init(day: RequestDay) {
        self.day = day
        let f = day.fields
        let fallback = day.suggestions.first ?? (day.original.isWork ? day.original : nil)
        let s = f.start ?? fallback?.start ?? ShiftClock(hour: 18, minute: 0)
        let e = f.end ?? fallback?.end ?? ShiftClock(hour: 23, minute: 0)
        _isWork = State(initialValue: f.isWork)
        _startHour = State(initialValue: min(max(s.hour, ShiftClock.startHours.first!), ShiftClock.startHours.last!))
        _startMinute = State(initialValue: ShiftClock.minutes.contains(s.minute) ? s.minute : 0)
        _endHour = State(initialValue: min(max(e.hour, ShiftClock.endHours.first!), ShiftClock.endHours.last!))
        _endMinute = State(initialValue: ShiftClock.minutes.contains(e.minute) ? e.minute : 0)
        _wantsContact = State(initialValue: f.isWork && f.wantsContact)
        _holidayType = State(initialValue: f.isWork || f.holidayType.isEmpty || f.holidayType == "0" ? "1" : f.holidayType)
        _reason = State(initialValue: f.holidayReason)
    }

    private var start: ShiftClock { ShiftClock(hour: startHour, minute: startMinute) }
    private var end: ShiftClock { ShiftClock(hour: endHour, minute: endMinute) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Picker("シフト", selection: $isWork.animation(Motion.snappy)) {
                        Text("出勤").tag(true)
                        Text("休み").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if isWork {
                        workCard
                        if !suggestions.isEmpty { suggestionRow }
                        Toggle(isOn: $wantsContact) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("管理者から連絡がほしい")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text("シフトの相談をしたいときにオンにします")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .tint(Theme.accent)
                        .card()
                    } else {
                        offCard
                    }

                    if day.original.shiftType.isEmpty == false, day.original != day.fields || day.isEdited {
                        Text("店舗に出している内容：\(day.original.isWork ? day.original.label : day.original.offLabel)")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 4)
                    }

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.negative)
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("変更する", action: commit)
                    .buttonStyle(GlassPrimaryButtonStyle(tint: Theme.accent))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - 部品

    private var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("\(day.date.month)/\(day.date.day)")
                .font(Theme.number(40, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("\(Fmt.weekdaySymbol(day.date.weekday))曜日")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(day.isRedDay ? Theme.sunday : Theme.weekdayColor(day.date.weekday))
            Spacer()
            Text(Fmt.relativeDay(day.date.date, now: model.now))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
    }

    private var workCard: some View {
        let valid = end > start
        let minutes = end.totalMinutes - start.totalMinutes
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(start.label)
                    .font(Theme.number(46, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("–")
                    .font(Theme.number(26, weight: .bold))
                    .foregroundStyle(Theme.faint)
                Text(end.label)
                    .font(Theme.number(34, weight: .heavy))
                    .foregroundStyle(valid ? Theme.muted : Theme.negative)
            }
            .monospacedDigit()
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(valid ? "\(Fmt.hours(Double(minutes)))時間 · 見込み \(Fmt.yen(estimate))" : "終了は開始より後にしてください")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valid ? Theme.muted : Theme.negative)
                .monospacedDigit()

            RangeBar(start: start, end: end, color: valid ? band.color : Theme.negative)

            HStack(spacing: 0) {
                wheel($startHour, ShiftClock.startHours) { "\($0)時" }
                wheel($startMinute, ShiftClock.minutes) { String(format: "%02d分", $0) }
                Text("〜")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.faint)
                    .frame(width: 22)
                wheel($endHour, ShiftClock.endHours) { "\($0)時" }
                wheel($endMinute, ShiftClock.minutes) { String(format: "%02d分", $0) }
            }
            .frame(height: 150)
            Text("24時より後は翌日の時刻です（26時＝翌2時）。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
        }
        .card(padding: 20)
        .animation(Motion.snappy, value: start)
        .animation(Motion.snappy, value: end)
    }

    private func wheel(_ selection: Binding<Int>, _ values: [Int], label: @escaping (Int) -> String) -> some View {
        Picker("", selection: selection) {
            ForEach(values, id: \.self) { Text(label($0)).tag($0) }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var suggestionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "よく使う時間")
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { f in
                        Button(f.label) {
                            guard let s = f.start, let e = f.end else { return }
                            withAnimation(Motion.snappy) {
                                startHour = min(max(s.hour, 5), 28); startMinute = s.minute
                                endHour = min(max(e.hour, 5), 37); endMinute = e.minute
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        .buttonStyle(GlassCapsuleButtonStyle())
                        .monospacedDigit()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var offCard: some View {
        let types = RequestFields.holidayTypes + (RequestFields.holidayTypes.contains(holidayType) ? [] : [holidayType])
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "休日区分")
            Picker("休日区分", selection: $holidayType.animation(Motion.snappy)) {
                ForEach(types, id: \.self) { Text(RequestFields.holidayLabel($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            if holidayType == "2" {
                TextField("理由（35文字まで）", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack {
                    Text("希望休は理由を添えて申請します。")
                    Spacer()
                    Text("\(reason.count)/35")
                        .foregroundStyle(reason.count > 35 ? Theme.negative : Theme.faint)
                        .monospacedDigit()
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            } else {
                Text(holidayType == "1" ? "休みとして申請します。どうしても休みたい日は「希望休」にします。" : "\(RequestFields.holidayLabel(holidayType))として申請します。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
        }
        .card(padding: 20)
    }

    // MARK: - 値

    private var band: ShiftBand {
        ShiftBand(start: day.date.date.addingTimeInterval(Double(start.totalMinutes) * 60))
    }

    private var estimate: Double {
        guard end > start else { return 0 }
        let base = day.date.date
        return PayCalculator.breakdown(start: base.addingTimeInterval(Double(start.totalMinutes) * 60),
                                       end: base.addingTimeInterval(Double(end.totalMinutes) * 60),
                                       rates: model.settings.rates).total
    }

    /// 店舗の案・基本の時間・この期間のほかの日で使っている時間
    private var suggestions: [RequestFields] {
        var list: [RequestFields] = []
        func add(_ f: RequestFields) {
            guard f.isWork, let s = f.start, let e = f.end, e > s else { return }
            let plain = RequestFields.work(s, e)
            if !list.contains(plain) { list.append(plain) }
        }
        day.suggestions.forEach(add)
        add(day.original)
        add(day.loaded)
        client.period?.days.forEach { add($0.fields) }
        return Array(list.prefix(8))
    }

    private func commit() {
        let input: RequestFields
        if isWork {
            input = .work(start, end, flexible: wantsContact)
        } else {
            input = RequestFields(shiftType: "2", fromHour: "", fromMinute: "", toHour: "", toMinute: "",
                                  flexibleType: "0", holidayType: holidayType, holidayReason: reason)
        }
        if !isWork && holidayType == "2" && reason.count > 35 {
            withAnimation(Motion.snappy) { error = "理由は35文字以内で入力してください。" }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        guard let p = client.period, let i = p.days.firstIndex(where: { $0.index == day.index }) else {
            dismiss()
            return
        }
        let result = ShiftRequestLogic.commit(input, for: p.days[i],
                                              yesterdayTo: ShiftRequestLogic.yesterdayTo(p.days, at: i),
                                              tomorrowFrom: ShiftRequestLogic.tomorrowFrom(p.days, at: i))
        switch result {
        case .success(let fields):
            client.update(day, to: fields)
            UISelectionFeedbackGenerator().selectionChanged()
            dismiss()
        case .failure(let e):
            withAnimation(Motion.snappy) { error = e.text }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

/// 5時〜翌日の帯に、希望の時間を描く
private struct RangeBar: View {
    let start: ShiftClock
    let end: ShiftClock
    let color: Color

    var body: some View {
        let lo = 5.0
        let hi = max(29.0, ceil(Double(end.totalMinutes) / 60))
        VStack(spacing: 4) {
            GeometryReader { g in
                let w = g.size.width
                let x = { (h: Double) -> CGFloat in CGFloat((h - lo) / (hi - lo)) * w }
                let s = Double(start.totalMinutes) / 60, e = Double(end.totalMinutes) / 60
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.fill)
                    // 深夜（22時〜29時）
                    Rectangle()
                        .fill(ShiftBand.night.color.opacity(0.12))
                        .frame(width: x(min(29, hi)) - x(22))
                        .offset(x: x(22))
                    if e > s {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color)
                            .frame(width: max(4, x(min(e, hi)) - x(max(s, lo))), height: 18)
                            .offset(x: x(max(s, lo)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(height: 26)
            HStack {
                ForEach(Array(stride(from: Int(lo), through: Int(hi), by: 6)), id: \.self) { h in
                    Text("\(h % 24)")
                        .font(.system(size: 10, weight: .semibold).width(.condensed))
                        .foregroundStyle(Theme.faint)
                    if h + 6 <= Int(hi) { Spacer(minLength: 0) }
                }
            }
        }
    }
}
