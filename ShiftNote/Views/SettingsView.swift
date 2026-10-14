import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.hasAccess {
                        Picker("カレンダー", selection: $model.settings.calendarIdentifier) {
                            Text("すべてのカレンダー").tag(String?.none)
                            ForEach(model.calendars, id: \.calendarIdentifier) { c in
                                Text(c.title).tag(Optional(c.calendarIdentifier))
                            }
                        }
                    } else {
                        Button("カレンダーへのアクセスを許可") {
                            Task { await model.requestAccess() }
                        }
                    }
                    LabeledContent("予定の名前") {
                        TextField("シフト", text: $model.settings.eventTitle)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("シフトの読み込み")
                } footer: {
                    Text("この名前の予定をシフトとして計算します。同じ時間の予定が複数のカレンダーにあっても1回として数えます。")
                }

                Section("時給") {
                    NumberRow(title: "平日", value: $model.settings.rates.weekday, prefix: "¥")
                    NumberRow(title: "土曜", value: $model.settings.rates.saturday, prefix: "¥")
                    NumberRow(title: "日曜", value: $model.settings.rates.sunday, prefix: "¥")
                }

                Section {
                    NumberRow(title: "深夜割増", value: $model.settings.rates.nightPremium, suffix: "%")
                    NumberRow(title: "交通費（1回）", value: $model.settings.rates.transport, prefix: "¥")
                } header: {
                    Text("手当")
                } footer: {
                    Text("深夜割増は22時〜5時の勤務にかかります。祝日は平日の時給で計算します。")
                }

                Section {
                    NumberRow(title: "6時間以上", value: $model.settings.rates.break6, suffix: "分")
                    NumberRow(title: "7時間以上", value: $model.settings.rates.break7, suffix: "分")
                    NumberRow(title: "8時間以上", value: $model.settings.rates.break8, suffix: "分")
                } header: {
                    Text("休憩")
                } footer: {
                    Text("勤務時間に応じて差し引く休憩です。")
                }

                Section {
                    Picker("締め日", selection: $model.settings.closingDay) {
                        Text("末日").tag(0)
                        ForEach(1...28, id: \.self) { Text("\($0)日").tag($0) }
                    }
                    Picker("支給", selection: $model.settings.payOffset) {
                        Text("当月").tag(0)
                        Text("翌月").tag(1)
                        Text("翌々月").tag(2)
                    }
                } header: {
                    Text("給料日")
                } footer: {
                    Text("年収の壁は、給料が支払われた月で数えます。")
                }

                Section("表示") {
                    Picker("週の始まり", selection: $model.settings.weekStart) {
                        ForEach(WeekStart.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Button("ウィジェットを更新") {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                } header: {
                    Text("ウィジェット")
                } footer: {
                    if SharedStore.isShared {
                        Text("ホーム画面やロック画面に「次のシフト」「今月の給与」「年収と年収の壁」「シフトカレンダー」を追加できます。ウィジェットはこの画面の設定を使います。")
                    } else {
                        Text("ウィジェットはアプリと保存場所が別なので、時給などはウィジェットを長押し →「ウィジェットを編集」でも入力してください。シフトはすべてのカレンダーから「シフト」の予定を探します。")
                    }
                }
            }
            .navigationTitle("設定")
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct NumberRow: View {
    let title: String
    @Binding var value: Double
    var prefix = ""
    var suffix = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if !prefix.isEmpty { Text(prefix).foregroundStyle(.secondary) }
            TextField(title, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .monospacedDigit()
            if !suffix.isEmpty { Text(suffix).foregroundStyle(.secondary) }
        }
    }
}
