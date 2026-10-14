import SwiftUI
import WidgetKit

struct SettingsScreen: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PayRow(title: "平日", value: $model.settings.rates.weekday)
                    PayRow(title: "土曜", value: $model.settings.rates.saturday)
                    PayRow(title: "日曜", value: $model.settings.rates.sunday)
                } header: {
                    Text("時給")
                } footer: {
                    Text("祝日は平日の時給で計算します。")
                }

                Section {
                    PayRow(title: "深夜割増", value: $model.settings.rates.nightPremium, unit: "%")
                    PayRow(title: "交通費（1回）", value: $model.settings.rates.transport)
                } header: {
                    Text("手当")
                } footer: {
                    Text("深夜割増は22時〜5時の勤務にかかります。")
                }

                Section {
                    PayRow(title: "6時間以上", value: $model.settings.rates.break6, unit: "分")
                    PayRow(title: "7時間以上", value: $model.settings.rates.break7, unit: "分")
                    PayRow(title: "8時間以上", value: $model.settings.rates.break8, unit: "分")
                } header: {
                    Text("休憩")
                } footer: {
                    Text("勤務時間に応じて差し引く休憩の長さです。")
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

                Section {
                    if model.widgetsShareSettings {
                        LabeledContent("設定の共有", value: "App Group")
                    } else {
                        Toggle("ウィジェットに設定を自動で渡す", isOn: $model.settings.syncViaCalendar)
                        if model.settings.syncViaCalendar {
                            LabeledContent("状態", value: syncLabel)
                        }
                    }
                    Button("ウィジェットを更新") {
                        model.scheduleWidgetSync(immediately: true)
                    }
                } header: {
                    Text("ウィジェット")
                } footer: {
                    if model.widgetsShareSettings {
                        Text("ウィジェットはこの画面の設定を使います。")
                    } else if model.settings.syncViaCalendar {
                        Text("時給などを、2001年1月1日の終日の予定（「Shift Note の設定」）のメモに保存してウィジェットに渡します。この予定を消すと、ウィジェットは編集画面の値を使います。")
                    } else {
                        Text("ウィジェットは、長押し →「ウィジェットを編集」で入力した時給を使います。")
                    }
                }

                Section("表示") {
                    Picker("週の始まり", selection: $model.settings.weekStart) {
                        ForEach(WeekStart.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("外観", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                }

                Section {
                    LabeledContent("バージョン", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                } footer: {
                    Text("給与はすべて控除前の見込みです。1分ごとに曜日別の時給と深夜割増を足し、休憩は勤務時間全体から差し引いて計算します。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("設定")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var syncLabel: String {
        switch model.syncStatus {
        case .idle: return "待機中"
        case .saved: return "保存済み"
        case .failed: return "保存できませんでした"
        }
    }
}

private struct PayRow: View {
    let title: String
    @Binding var value: Double
    var unit = "円"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.number(19, weight: .bold))
                .frame(maxWidth: 110)
            Text(unit)
                .foregroundStyle(Theme.muted)
        }
    }
}
