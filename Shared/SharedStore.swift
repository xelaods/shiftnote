import Foundation

/// アプリとウィジェットで設定を共有する（App Group が使えるときはその中、使えないときはアプリだけ）
enum SharedStore {
    static let appGroupID: String? = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String,
              !id.isEmpty, !id.contains("$(") else { return nil }
        return id
    }()

    /// App Group が実際に使えるか（署名に App Group が入っているか）
    static var isShared: Bool {
        guard let id = appGroupID else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    static var defaults: UserDefaults {
        if isShared, let id = appGroupID, let d = UserDefaults(suiteName: id) { return d }
        return .standard
    }

    private static let key = "settings.v1"

    static func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    static func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
