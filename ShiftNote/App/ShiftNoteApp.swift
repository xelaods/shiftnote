import SwiftUI

@main
struct ShiftNoteApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environmentObject(model)
        }
    }
}

struct AppRoot: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue
    @AppStorage("onboarded") private var onboarded = false
    @State private var launching = !AppModel.isDemo
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                if ProcessInfo.processInfo.arguments.contains("-gallery") {
                    WidgetGallery()
                } else if onboarded || model.isDemo {
                    MainTabView()
                        .transition(.cinematic)
                } else {
                    OnboardingView {
                        withAnimation(Motion.cinematic) { onboarded = true }
                    }
                    .transition(.cinematic)
                }
            }
            .scaleEffect(launching ? 0.92 : 1)
            .blur(radius: launching ? 18 : 0)
            .allowsHitTesting(!launching)

            if launching {
                LaunchView {
                    withAnimation(Motion.cinematic) { launching = false }
                }
                .zIndex(1)
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reload() }
        }
    }
}

/// 下のタブ：ホーム・カレンダー・年収・設定
struct MainTabView: View {
    enum Tab: Hashable { case home, calendar, income, settings }

    @EnvironmentObject var model: AppModel
    @State private var tab: Tab = MainTabView.initialTab
    @State private var sheetDay: DayKey?

    private static var initialTab: Tab {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-tab"), i + 1 < args.count else { return .home }
        switch args[i + 1] {
        case "calendar": return .calendar
        case "income": return .income
        case "settings": return .settings
        default: return .home
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(openDay: { sheetDay = $0 }, openIncome: { withAnimation(Motion.cinematicFast) { tab = .income } })
                .tabItem { Label("ホーム", systemImage: "clock") }
                .tag(Tab.home)
            CalendarScreen(openDay: { sheetDay = $0 })
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(Tab.calendar)
            IncomeScreen()
                .tabItem { Label("年収", systemImage: "chart.bar.xaxis") }
                .tag(Tab.income)
            SettingsScreen()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .sheet(item: $sheetDay) { day in
            DaySheet(day: day)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        // ウィジェットから開いたとき（shiftnote://calendar・shiftnote://income・shiftnote://day/20261014）
        .onOpenURL { url in
            guard url.scheme == "shiftnote" else { return }
            withAnimation(Motion.cinematicFast) {
                switch url.host {
                case "calendar": tab = .calendar
                case "income": tab = .income
                case "settings": tab = .settings
                case "day":
                    tab = .home
                    if let id = Int(url.lastPathComponent) {
                        sheetDay = DayKey(year: id / 10000, month: id / 100 % 100, day: id % 100)
                    }
                default: tab = .home
                }
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-day") { sheetDay = DayKey(model.now) }
        }
    }
}

/// 起動時：タイムカードが差し込まれて、ロゴにピントが合う
struct LaunchView: View {
    let onFinish: () -> Void
    @State private var phase = 0

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.card)
                        .frame(width: 92, height: 108)
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: 92, height: 30)
                            .mask(alignment: .top) { Rectangle().frame(height: 30) }
                        Spacer()
                    }
                    .frame(height: 108)
                    Text("¥")
                        .font(Theme.number(46, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .offset(y: 10)
                }
                .offset(y: phase >= 1 ? 0 : 40)
                .scaleEffect(phase >= 1 ? 1 : 0.86)
                .blur(radius: phase >= 1 ? 0 : 12)
                .opacity(phase >= 1 ? 1 : 0)

                Text("Shift Note")
                    .font(.system(size: 30, weight: .heavy).width(.condensed))
                    .foregroundStyle(Theme.ink)
                    .tracking(phase >= 2 ? 0.5 : 6)
                    .blur(radius: phase >= 2 ? 0 : 8)
                    .opacity(phase >= 2 ? 1 : 0)
            }
            .scaleEffect(phase >= 3 ? 1.06 : 1)
            .blur(radius: phase >= 3 ? 14 : 0)
            .opacity(phase >= 3 ? 0 : 1)
        }
        .opacity(phase >= 3 ? 0 : 1)
        .task {
            withAnimation(Motion.cinematic) { phase = 1 }
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(Motion.cinematic) { phase = 2 }
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(Motion.cinematicFast) { phase = 3 }
            try? await Task.sleep(nanoseconds: 250_000_000)
            onFinish()
        }
    }
}
