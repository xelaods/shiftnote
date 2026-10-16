import SwiftUI
import UIKit
import WebKit

/// シフコンとのやり取り。
/// 画面には出さない WKWebView でシフコンの従業員ページを開き、フォームの値を読み書きする
/// （ボタンを押したときと同じ送信をするので、シフコン側の動きはブラウザで申請したときと変わらない）。
/// ログインが必要なときだけ、同じ WKWebView をシートに出して入力してもらう。
@MainActor
final class ShifconClient: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle, loading, ready, needsLogin, failed(String)
    }

    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var isError = false
    }

    static let topURL = URL(string: "https://shifucon.ppihgroup.com/staffpage/")!
    static let autoLoginKey = "shifconAutoLogin"

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var period: RequestPeriod?
    @Published private(set) var busy = false
    @Published var showLogin = false
    @Published var notice: Notice?

    private(set) lazy var webView: WKWebView = makeWebView()
    private var loadWaiter: CheckedContinuation<Void, Never>?
    private var waiterID = 0
    private var submitFailed = false
    private var autoLoginTried = false
    private var pendingLogin: [String: String]?
    private var cookiesRestored = false
    private var lastLoaded: Date?

    var isDemo: Bool { AppModel.isDemo }
    var hasSavedLogin: Bool { Keychain.data("login") != nil }
    private var autoLoginEnabled: Bool { UserDefaults.standard.object(forKey: Self.autoLoginKey) as? Bool ?? true }

    override init() {
        super.init()
        if AppModel.isDemo {
            period = RequestPeriod.demo()
            phase = .ready
        }
    }

    // MARK: - 操作

    /// 申請タブを開いたとき
    func appear() {
        guard !isDemo else { return }
        if phase == .idle {
            Task { await refresh() }
        } else if let last = lastLoaded, Date().timeIntervalSince(last) > 600, !(period?.hasEdits ?? false), !busy {
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard !isDemo else { return }
        await restoreCookiesIfNeeded()
        if period == nil { phase = .loading }
        busy = true
        defer { busy = false }
        await navigate { $0.load(URLRequest(url: Self.topURL)) }
    }

    /// 前（-1）・次（+1）の期間
    func move(_ step: Int) async {
        guard let p = period, step < 0 ? p.canGoBack : p.canGoNext else { return }
        if isDemo { return }
        busy = true
        defer { busy = false }
        await submit(ShifconScripts.submit(mode: step < 0 ? "date_back" : "date_next"))
    }

    /// 前回の申請内容をコピー（シフコンの「前回の申請内容をコピー」と同じ）
    func copyPrevious() async {
        guard !isDemo, period?.canCopy == true else { return }
        busy = true
        defer { busy = false }
        if await submit(ShifconScripts.submit(mode: "date_copy")) {
            notice = Notice(text: "前回の申請内容をコピーしました。内容を確かめて申請してください。")
        }
    }

    func update(_ day: RequestDay, to fields: RequestFields) {
        guard var p = period, let i = p.days.firstIndex(where: { $0.index == day.index }) else { return }
        p.days[i].fields = fields
        period = p
    }

    func discardEdits() {
        guard var p = period else { return }
        for i in p.days.indices { p.days[i].fields = p.days[i].loaded }
        period = p
    }

    /// 申請する。成功したら true
    @discardableResult
    func apply() async -> Bool {
        guard let p = period, p.isOpen else { return false }
        if let message = ShiftRequestLogic.applyCheck(p.days) {
            notice = Notice(text: message, isError: true)
            return false
        }
        if isDemo {
            var done = p
            for i in done.days.indices {
                let f = done.days[i].fields
                done.days[i] = RequestDay(index: done.days[i].index, date: done.days[i].date, isPublicHoliday: done.days[i].isPublicHoliday,
                                          editable: done.days[i].editable, fields: f, loaded: f, original: f,
                                          originalUpdateFlag: done.days[i].originalUpdateFlag,
                                          initialYesterdayTo: done.days[i].initialYesterdayTo, initialTomorrowFrom: done.days[i].initialTomorrowFrom,
                                          suggestions: done.days[i].suggestions)
            }
            done.statusText = "申請済"
            done.applyTitle = "再申請"
            period = done
            notice = Notice(text: "申請しました")
            return true
        }

        let sent = p.days
        let flags = ShiftRequestLogic.updateFlags(sent)
        busy = true
        defer { busy = false }
        guard await submit(ShifconScripts.apply(sent, flags: flags)) else { return false }

        // 送信後の画面を読み込み直して、店舗側の値になったか確かめる
        if period?.from != p.from || phase != .ready {
            await refresh()
        }
        guard let now = period, now.from == p.from else {
            notice = Notice(text: "申請を送信しました。シフコンで内容を確かめてください。")
            return true
        }
        let missing = ShiftRequestLogic.unreflectedDays(sent: sent, reloaded: now)
        if missing.isEmpty {
            notice = Notice(text: now.messages.first ?? "申請しました")
            return true
        }
        // 反映されていない日は、入力した内容を戻しておく（もう一度申請できるように）
        var restored = now
        for i in restored.days.indices where restored.days[i].editable {
            if let mine = sent.first(where: { $0.date == restored.days[i].date }), mine.isEdited {
                restored.days[i].fields = mine.fields
            }
        }
        period = restored
        let dates = missing.map { "\($0.month)/\($0.day)" }.joined(separator: "・")
        let reason = now.messages.first.map { "（\($0)）" } ?? ""
        notice = Notice(text: "\(dates) が反映されていません\(reason)。もう一度申請してください。", isError: true)
        return false
    }

    /// 保存したログイン情報と Cookie を消す
    func forgetLogin() async {
        Keychain.set(Data?.none, for: "login")
        Keychain.set(Data?.none, for: "cookies")
        pendingLogin = nil
        let store = webView.configuration.websiteDataStore.httpCookieStore
        for c in await store.allCookies() where c.domain.contains("ppihgroup.com") {
            await store.deleteCookie(c)
        }
        period = nil
        phase = .idle
    }

    // MARK: - 読み込み

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: ShifconScripts.captureLogin, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        controller.add(WeakScriptHandler(self), name: "shifconLogin")
        config.userContentController = controller
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        return web
    }

    /// ページの読み込みを始めて、終わる（読み取りまで済む）のを待つ
    private func navigate(_ action: (WKWebView) -> Void) async {
        waiterID += 1
        let id = waiterID
        loadWaiter?.resume()
        loadWaiter = nil
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            loadWaiter = c
            action(webView)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                self?.timeout(id)
            }
        }
    }

    private func resumeWaiter() {
        let w = loadWaiter
        loadWaiter = nil
        w?.resume()
    }

    private func timeout(_ id: Int) {
        guard id == waiterID, loadWaiter != nil else { return }
        resumeWaiter()
        if period == nil, phase == .loading {
            phase = .failed("シフコンに接続できませんでした。")
        }
    }

    /// シフコンの画面のスクリプトを動かして送信し、次の画面を待つ。送信できなかったら false
    @discardableResult
    private func submit(_ js: String) async -> Bool {
        submitFailed = false
        await navigate { web in
            Task { @MainActor [weak self] in
                let result = try? await web.evaluateJavaScript(js)
                if (result as? String) != "ok" {
                    self?.submitFailed = true
                    self?.resumeWaiter()
                }
            }
        }
        if submitFailed {
            notice = Notice(text: "シフコンの画面を操作できませんでした。読み込み直してください。", isError: true)
            await refresh()
            return false
        }
        return true
    }

    /// ページを読み終えたとき：申請画面なら読み取り、ログイン画面なら自動ログインかシートを出す
    private func pageLoaded() async {
        defer { resumeWaiter() }
        guard let json = try? await webView.evaluateJavaScript(ShifconScripts.scrape) as? String,
              let data = json.data(using: .utf8),
              let page = try? JSONDecoder().decode(ScrapedPage.self, from: data) else { return }

        if let p = page.period() {
            period = p
            phase = .ready
            lastLoaded = Date()
            showLogin = false
            autoLoginTried = false
            if let login = pendingLogin, autoLoginEnabled {
                Keychain.set(login, for: "login")
            }
            pendingLogin = nil
            await saveCookies()
            return
        }

        if page.hasPassword == true, autoLoginEnabled, !autoLoginTried, let login = Keychain.dictionary("login") {
            autoLoginTried = true
            let url = webView.url
            _ = try? await webView.evaluateJavaScript(ShifconScripts.autoLogin(login))
            // 画面が変わらなければ自分で入力してもらう
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard let self, self.phase != .ready, self.webView.url == url, !self.webView.isLoading else { return }
                self.phase = .needsLogin
                self.showLogin = true
            }
            return
        }
        phase = .needsLogin
        showLogin = true
    }

    fileprivate func received(login json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var values: [String: String] = [:]
        for (k, v) in dict { values[k] = "\(v)" }
        if !values.isEmpty {
            pendingLogin = values
            autoLoginTried = false
        }
    }

    // MARK: - Cookie（ログインを保つ）

    private func saveCookies() async {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        let list: [[String: Any]] = cookies.filter { $0.domain.contains("ppihgroup.com") }.compactMap { (c: HTTPCookie) -> [String: Any]? in
            guard let props = c.properties else { return nil }
            var d: [String: Any] = [:]
            for (k, v) in props {
                if v is String || v is Date || v is NSNumber {
                    d[k.rawValue] = v
                } else if let u = v as? URL {
                    d[k.rawValue] = u.absoluteString
                }
            }
            return d
        }
        if let data = try? PropertyListSerialization.data(fromPropertyList: list, format: .binary, options: 0) {
            Keychain.set(data, for: "cookies")
        }
    }

    private func restoreCookiesIfNeeded() async {
        guard !cookiesRestored else { return }
        cookiesRestored = true
        guard let data = Keychain.data("cookies"),
              let list = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [[String: Any]] else { return }
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let existing = await store.allCookies()
        for item in list {
            var props: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in item { props[HTTPCookiePropertyKey(k)] = v }
            props.removeValue(forKey: .discard)
            if props[.expires] == nil { props[.expires] = Date().addingTimeInterval(14 * 86400) }
            guard let cookie = HTTPCookie(properties: props) else { continue }
            if existing.contains(where: { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }) { continue }
            await store.setCookie(cookie)
        }
    }
}

// MARK: - WKWebView のデリゲート

extension ShifconClient: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { await pageLoaded() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadFailed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFailed(error)
    }

    private func loadFailed(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        if period == nil || phase == .loading {
            phase = .failed(error.localizedDescription)
        } else {
            notice = Notice(text: error.localizedDescription, isError: true)
        }
        resumeWaiter()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(), !["http", "https", "about", "javascript", "data", "blob"].contains(scheme) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        notice = Notice(text: message, isError: true)
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}

/// WKUserContentController が ShifconClient を強参照しないための中継
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var client: ShifconClient?
    init(_ client: ShifconClient) { self.client = client }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        Task { @MainActor [weak client] in client?.received(login: body) }
    }
}

// MARK: - 見本（スクリーンショット用）

extension RequestPeriod {
    static func demo(now: Date = Date()) -> RequestPeriod {
        let today = DayKey(now)
        let start = today.adding(days: 14).startOfWeek(firstWeekday: 1)
        let patterns: [(Int, Int, Int, Int)?] = [(10, 0, 23, 0), nil, (20, 0, 23, 0), (18, 0, 23, 0), (20, 0, 26, 0), (10, 0, 26, 0), (10, 0, 26, 0)]
        var days: [RequestDay] = []
        for i in 0..<14 {
            let date = start.adding(days: i)
            let f: RequestFields
            if let p = patterns[i % 7] {
                f = .work(ShiftClock(hour: p.0, minute: p.1), ShiftClock(hour: p.2, minute: p.3))
            } else {
                f = .dayOff
            }
            var fields = f
            if i == 9 {
                fields = RequestFields(shiftType: "2", fromHour: "", fromMinute: "", toHour: "", toMinute: "",
                                       flexibleType: "0", holidayType: "2", holidayReason: "大学の試験")
            }
            days.append(RequestDay(index: i, date: date, isPublicHoliday: false, editable: true,
                                   fields: fields, loaded: f, original: f, originalUpdateFlag: "0",
                                   initialYesterdayTo: i == 0 ? "2600" : "", initialTomorrowFrom: i == 13 ? "1000" : "",
                                   suggestions: [.work(ShiftClock(hour: 18, minute: 0), ShiftClock(hour: 23, minute: 0))]))
        }
        let end = start.adding(days: 13)
        let deadline = start.adding(days: -13)
        return RequestPeriod(from: start, to: end, staffName: "見本", storeName: "見本店",
                             deadline: "\(deadline.month)/\(deadline.day)(\(Fmt.weekdaySymbol(deadline.weekday)))",
                             infos: [RequestInfo(label: "\(start.month)月予定", value: "235:00"),
                                     RequestInfo(label: "個人設定時間", value: "0:00～76:00")],
                             days: days, canGoBack: true, canGoNext: true, canCopy: true, isOpen: true,
                             statusText: "申請済", applyTitle: "再申請", serverCanApply: false, messages: [])
    }
}
