import SwiftUI
import UIKit
import WebKit

/// 申請：シフコンの2週間ごとのシフト希望を、アプリから出す
struct RequestScreen: View {
    @EnvironmentObject var client: ShifconClient
    @EnvironmentObject var model: AppModel
    @State private var editing: RequestDay?
    @State private var confirmApply = false
    @State private var confirmCopy = false
    @State private var pendingMove: Int?
    @State private var direction: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(eyebrow: eyebrow, title: "シフト申請") {
                        Button {
                            Task { await client.refresh() }
                        } label: {
                            if client.busy {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        .disabled(client.busy || client.isDemo)
                    }
                    .cinematicReveal(0)
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await client.refresh() }
            .safeAreaInset(edge: .bottom) { applyBar }
            .overlay(alignment: .top) { noticeToast }
        }
        .onAppear { client.appear() }
        .sheet(item: $editing) { day in
            RequestEditor(day: day)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $client.showLogin) {
            ShifconLoginSheet()
        }
        .confirmationDialog("この内容で申請しますか？", isPresented: $confirmApply, titleVisibility: .visible) {
            Button(applyLabel) { Task { await client.apply() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let p = client.period {
                Text("\(rangeText(p))の希望をシフコンに送ります。")
            }
        }
        .confirmationDialog("前回の申請内容をコピーしますか？", isPresented: $confirmCopy, titleVisibility: .visible) {
            Button("コピーする") { Task { await client.copyPrevious() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("前の期間に申請した内容を、この期間に写します。まだ申請はされません。")
        }
        .confirmationDialog("変更を破棄しますか？", isPresented: Binding(get: { pendingMove != nil }, set: { if !$0 { pendingMove = nil } }), titleVisibility: .visible) {
            Button("破棄して移動", role: .destructive) {
                if let step = pendingMove { go(step, force: true) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("申請していない変更があります。")
        }
    }

    // MARK: - 中身

    @ViewBuilder
    private var content: some View {
        if client.phase == .needsLogin {
            LoginCard().cinematicReveal(1)
        }
        if let p = client.period {
            Group {
                PeriodCard(period: p, busy: client.busy, move: { go($0) })
                if !p.messages.isEmpty {
                    MessagesCard(messages: p.messages)
                }
                DaysCard(period: p) { editing = $0 }
                if p.isOpen && p.canCopy {
                    Button {
                        confirmCopy = true
                    } label: {
                        Label("前回の申請内容をコピー", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassCapsuleButtonStyle())
                    .disabled(client.busy)
                }
                if !p.isOpen {
                    Text("この期間は締め切られています。左右の矢印で申請中の期間に切り替えられます。")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                }
            }
            .id(p.from)
            .transition(.cinematicSlide(direction))
            .cinematicReveal(2)
        } else {
            switch client.phase {
            case .failed(let message):
                FailedCard(message: message).cinematicReveal(1)
            case .needsLogin:
                EmptyView()
            default:
                LoadingCard().cinematicReveal(1)
            }
        }
    }

    // MARK: - 申請ボタン

    @ViewBuilder
    private var applyBar: some View {
        if let p = client.period, p.isOpen, p.hasEdits || p.canApply {
            VStack(spacing: 10) {
                HStack {
                    Text(p.hasEdits ? "\(p.editedCount)日分を変更しました" : "まだ申請していない内容があります")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    if p.hasEdits {
                        Button("元に戻す") {
                            withAnimation(Motion.snappy) { client.discardEdits() }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .disabled(client.busy)
                    }
                }
                Button {
                    confirmApply = true
                } label: {
                    HStack(spacing: 8) {
                        if client.busy { ProgressView().tint(Theme.paper) }
                        Text(applyLabel)
                    }
                }
                .buttonStyle(GlassPrimaryButtonStyle(tint: Theme.accent))
                .disabled(client.busy || !p.canApply)
            }
            .padding(16)
            .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var noticeToast: some View {
        if let n = client.notice {
            HStack(spacing: 10) {
                Image(systemName: n.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(n.isError ? Theme.warning : Theme.accent)
                Text(n.text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { withAnimation(Motion.snappy) { client.notice = nil } }
            .task(id: n.id) {
                try? await Task.sleep(nanoseconds: n.isError ? 7_000_000_000 : 3_500_000_000)
                if client.notice?.id == n.id {
                    withAnimation(Motion.snappy) { client.notice = nil }
                }
            }
        }
    }

    // MARK: - 動作

    private func go(_ step: Int, force: Bool = false) {
        if !force, client.period?.hasEdits == true {
            pendingMove = step
            return
        }
        pendingMove = nil
        direction = step < 0 ? -1 : 1
        Task { await client.move(step) }
    }

    private var applyLabel: String {
        (client.period?.applyTitle?.isEmpty == false ? client.period!.applyTitle! : "申請") + "する"
    }

    private var eyebrow: String {
        guard let p = client.period else { return "シフコン" }
        var parts: [String] = []
        if let d = p.deadline, !d.isEmpty { parts.append("締切 \(d)") }
        if !p.storeName.isEmpty { parts.append(p.storeName) }
        return parts.isEmpty ? "シフコン" : parts.joined(separator: " · ")
    }
}

private func rangeText(_ p: RequestPeriod) -> String {
    "\(p.from.month)/\(p.from.day)〜\(p.to.month)/\(p.to.day)"
}

// MARK: - 期間

private struct PeriodCard: View {
    let period: RequestPeriod
    let busy: Bool
    let move: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(GlassCircleButtonStyle(size: 38))
                    .disabled(!period.canGoBack || busy)
                    .opacity(period.canGoBack ? 1 : 0.35)
                Spacer()
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        dayText(period.from)
                        Text("–")
                            .font(Theme.number(20, weight: .bold))
                            .foregroundStyle(Theme.faint)
                        dayText(period.to)
                    }
                    StatusBadge(period: period)
                }
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(GlassCircleButtonStyle(size: 38))
                    .disabled(!period.canGoNext || busy)
                    .opacity(period.canGoNext ? 1 : 0.35)
            }
            if period.deadline != nil || !period.infos.isEmpty {
                Divider().overlay(Theme.line)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .topLeading), count: 3),
                          alignment: .leading, spacing: 12) {
                    if let d = period.deadline {
                        StatTile(title: "締切", value: d, tint: period.isOpen ? Theme.ink : Theme.muted)
                    }
                    ForEach(period.infos, id: \.self) { info in
                        StatTile(title: info.label, value: info.value.isEmpty ? "—" : info.value)
                    }
                }
            }
        }
        .card(padding: 18)
    }

    private func dayText(_ d: DayKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(d.month)/\(d.day)")
                .font(Theme.number(28, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(Fmt.weekdaySymbol(d.weekday))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.muted)
        }
        .monospacedDigit()
    }
}

private struct StatusBadge: View {
    let period: RequestPeriod

    var body: some View {
        let (text, icon, color): (String, String, Color) = {
            if !period.isOpen { return ("締切済み", "lock.fill", Theme.muted) }
            let s = period.statusText ?? ""
            if s.contains("済") { return (s, "checkmark.circle.fill", Theme.accent) }
            return (s.isEmpty ? "未申請" : s, "exclamationmark.circle.fill", Theme.warning)
        }()
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct MessagesCard: View {
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(messages, id: \.self) { m in
                Label(m, systemImage: "info.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
        }
        .card()
    }
}

// MARK: - 2週間の一覧

private struct DaysCard: View {
    @EnvironmentObject var model: AppModel
    let period: RequestPeriod
    let open: (RequestDay) -> Void

    var body: some View {
        let work = period.days.filter { $0.fields.isWork }
        let minutes = work.compactMap(\.fields.durationMinutes).reduce(0, +)
        let pay = work.reduce(0.0) { $0 + estimate($1) }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "希望するシフト")
                Spacer()
                Text("出勤\(work.count)日 · \(Fmt.hours(Double(minutes)))時間 · 見込み\(Fmt.yen(pay))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.bottom, 6)
            ForEach(Array(period.days.enumerated()), id: \.element.id) { i, day in
                if i > 0 {
                    Rectangle()
                        .fill(day.date.weekday == 1 ? Theme.ink.opacity(0.18) : Theme.line)
                        .frame(height: day.date.weekday == 1 ? 1.5 : 0.75)
                }
                let canEdit = period.isOpen && day.editable
                Button { open(day) } label: {
                    RequestDayRow(day: day, canEdit: canEdit)
                }
                .buttonStyle(PressableCardStyle())
                .disabled(!canEdit)
            }
        }
        .card()
    }

    private func estimate(_ day: RequestDay) -> Double {
        guard let s = day.fields.start, let e = day.fields.end, e > s else { return 0 }
        let base = day.date.date
        return PayCalculator.breakdown(start: base.addingTimeInterval(Double(s.totalMinutes) * 60),
                                       end: base.addingTimeInterval(Double(e.totalMinutes) * 60),
                                       rates: model.settings.rates).total
    }
}

private struct RequestDayRow: View {
    let day: RequestDay
    let canEdit: Bool

    var body: some View {
        let f = day.fields
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(day.date.day)")
                    .font(Theme.number(22, weight: .black))
                    .foregroundStyle(day.isRedDay ? Theme.sunday : day.date.weekday == 7 ? Theme.saturday : Theme.ink)
                Text(Fmt.weekdaySymbol(day.date.weekday))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .frame(width: 34)

            Capsule()
                .fill(bandColor)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                if f.isWork {
                    Text(f.label)
                        .font(Theme.number(20, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                } else {
                    Text(f.offLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(f.holidayType == "2" ? Theme.warning : Theme.muted)
                    if !f.holidayReason.isEmpty {
                        Text(f.holidayReason)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 4)
            if day.isEdited {
                tag("変更", Theme.accent)
            } else if canEdit && f != day.original && !day.original.shiftType.isEmpty {
                tag("未申請", Theme.warning)
            }
            if canEdit {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.faint)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .opacity(canEdit ? 1 : 0.6)
    }

    private var bandColor: Color {
        guard day.fields.isWork, let s = day.fields.start else { return Theme.fill }
        return ShiftBand(start: day.date.date.addingTimeInterval(Double(s.totalMinutes) * 60)).color
    }

    private var detail: String {
        var parts: [String] = []
        if let m = day.fields.durationMinutes { parts.append("\(Fmt.hours(Double(m)))時間") }
        if day.fields.wantsContact { parts.append(day.fields.flexibleType == "2" ? "調整済み" : "連絡希望") }
        return parts.joined(separator: " · ")
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.onBand)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

// MARK: - ログイン・読み込み中・エラー

private struct LoginCard: View {
    @EnvironmentObject var client: ShifconClient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("シフコンにログイン")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("シフコンの従業員ページにログインすると、ここから2週間ごとのシフトを申請できます。入力したログイン情報はこの iPhone のキーチェーンに保存され、次からは自動でログインします。")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Button("ログイン") { client.showLogin = true }
                .buttonStyle(GlassPrimaryButtonStyle(tint: Theme.accent))
                .padding(.top, 4)
        }
        .card(padding: 20)
    }
}

private struct LoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("シフコンを読み込んでいます…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .card()
    }
}

private struct FailedCard: View {
    @EnvironmentObject var client: ShifconClient
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.warning)
            Text("読み込めませんでした")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Button("もう一度") { Task { await client.refresh() } }
                .buttonStyle(GlassPrimaryButtonStyle(tint: Theme.accent))
                .padding(.top, 4)
        }
        .card(padding: 20)
    }
}

// MARK: - ログイン画面（シフコンのページをそのまま出す）

struct ShifconLoginSheet: View {
    @EnvironmentObject var client: ShifconClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebViewHost(webView: client.webView)
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Text("ログインすると、自動で申請画面に戻ります。")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.paper)
                }
                .navigationTitle("シフコン")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            client.webView.load(URLRequest(url: ShifconClient.topURL))
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        }
        .onAppear {
            if client.webView.url == nil {
                client.webView.load(URLRequest(url: ShifconClient.topURL))
            }
        }
    }
}

/// アプリが持っている WKWebView をそのまま画面に載せる
struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        attach(to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if webView.superview !== container { attach(to: container) }
    }

    static func dismantleUIView(_ container: UIView, coordinator: ()) {
        container.subviews.forEach { $0.removeFromSuperview() }
    }

    private func attach(to container: UIView) {
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(webView)
    }
}
