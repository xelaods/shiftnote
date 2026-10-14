import SwiftUI
import UIKit

/// 初回だけ：カレンダーの許可 → 時給の入力
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    let onFinish: () -> Void
    @State private var step = 0

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            switch step {
            case 0:
                welcome.transition(.cinematicSlide(1))
            case 1:
                rates.transition(.cinematicSlide(1))
            default:
                widgets.transition(.cinematicSlide(1))
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Shift Note")
                .font(.system(size: 44, weight: .heavy).width(.condensed))
                .foregroundStyle(Theme.ink)
                .cinematicReveal(0)
            Text("カレンダーのシフトから、\n給与と年収を自動で計算します。")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
                .cinematicReveal(1)
            VStack(alignment: .leading, spacing: 18) {
                feature("clock", "次のシフトと、勤務中にいくら稼いだか")
                feature("yensign", "今月の予想給与・勤務時間・実質時給")
                feature("chart.bar.xaxis", "年収の見込みと、年収の壁までの残り")
                feature("square.grid.2x2", "ホーム画面とロック画面のウィジェット")
            }
            .padding(.top, 36)
            .cinematicReveal(2)
            Spacer()
            Text("カレンダーにある「シフト」という名前の予定を読みます。シフトの予定を書き換えることはありません。")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 16)
                .cinematicReveal(3)
            Button {
                Task {
                    await model.requestAccess()
                    withAnimation(Motion.cinematic) { step = 1 }
                }
            } label: {
                Text("カレンダーへのアクセスを許可")
            }
            .buttonStyle(GlassPrimaryButtonStyle())
            .cinematicReveal(4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
    }

    private var rates: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("時給を教えてください")
                .font(.system(size: 30, weight: .heavy).width(.condensed))
                .foregroundStyle(Theme.ink)
                .padding(.top, 40)
                .cinematicReveal(0)
            Text("あとから設定タブでいつでも変えられます。")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
                .cinematicReveal(1)
            VStack(spacing: 0) {
                RateField(title: "平日", value: $model.settings.rates.weekday)
                Divider()
                RateField(title: "土曜", value: $model.settings.rates.saturday)
                Divider()
                RateField(title: "日曜", value: $model.settings.rates.sunday)
                Divider()
                RateField(title: "交通費（1回）", value: $model.settings.rates.transport)
            }
            .card(padding: 4)
            .padding(.top, 24)
            .cinematicReveal(2)
            Text("深夜割増（22時〜5時・25%）と休憩（6時間以上で30分など）は初期値で入っています。")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .padding(.top, 12)
                .cinematicReveal(3)
            Spacer()
            Button("次へ") {
                hideKeyboard()
                withAnimation(Motion.cinematic) { step = 2 }
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var widgets: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ウィジェット")
                .font(.system(size: 30, weight: .heavy).width(.condensed))
                .foregroundStyle(Theme.ink)
                .padding(.top, 40)
                .cinematicReveal(0)
            Text("ホーム画面を長押しして「＋」から「Shift Note」を追加すると、アプリを開かずに給与やシフトを確認できます。")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
                .cinematicReveal(1)
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $model.settings.syncViaCalendar) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ウィジェットに設定を自動で渡す")
                            .font(.system(size: 16, weight: .semibold))
                        Text("時給などを、2001年1月1日の終日の予定のメモに保存してウィジェットと共有します。オフにすると、ウィジェットの編集画面で時給を入力します。")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .tint(Theme.accent)
            }
            .card()
            .padding(.top, 24)
            .opacity(model.widgetsShareSettings ? 0 : 1)
            .cinematicReveal(2)
            Spacer()
            Button("はじめる") {
                model.scheduleWidgetSync(immediately: true)
                onFinish()
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

struct RateField: View {
    let title: String
    @Binding var value: Double
    var unit = "円"

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.number(22, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: 120)
            Text(unit)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
