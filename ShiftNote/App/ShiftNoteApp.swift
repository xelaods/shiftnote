import SwiftUI

@main
struct ShiftNoteApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.reload() }
                }
        }
    }
}

struct ContentView: View {
    @AppStorage("selectedTab") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("概要", systemImage: "yensign.circle") }
                .tag(0)
            ShiftCalendarScreen()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(1)
            IncomeView()
                .tabItem { Label("年収", systemImage: "chart.bar") }
                .tag(2)
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(3)
        }
    }
}
