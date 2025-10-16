import Foundation
import Combine

/// Supported languages in the application
enum AppLanguage: String, CaseIterable, Codable {
    case english = "en"
    case chinese = "zh-Hans" // Simplified Chinese
    case traditionalChinese = "zh-Hant" // Traditional Chinese
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"
    case arabic = "ar"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        }
    }
    
    /// Get locale for this language
    var locale: Locale {
        return Locale(identifier: self.rawValue)
    }
    
    /// Get system language
    static func systemLanguage() -> AppLanguage {
        let localeId = Locale.current.identifier
        
        if localeId.starts(with: "zh-Hans") {
            return .chinese
        } else if localeId.starts(with: "zh-Hant") || localeId.starts(with: "zh-HK") || localeId.starts(with: "zh-TW") {
            return .traditionalChinese
        } else if localeId.starts(with: "es") {
            return .spanish
        } else if localeId.starts(with: "fr") {
            return .french
        } else if localeId.starts(with: "de") {
            return .german
        } else if localeId.starts(with: "ja") {
            return .japanese
        } else if localeId.starts(with: "ko") {
            return .korean
        } else if localeId.starts(with: "ru") {
            return .russian
        } else if localeId.starts(with: "ar") {
            return .arabic
        } else {
            return .english
        }
    }
}

/// Manager for handling app localization
class LocalizationManager: ObservableObject {
    // MARK: - Properties
    
    static let shared = LocalizationManager()
    
    /// 存储键
    /// Storage key
    private let languageStorageKey = "com.easytime.keyflash.selectedLanguage"
    
    /// 当前语言
    /// Current language
    @Published private(set) var currentLanguage: AppLanguage {
        didSet {
            // 保存选择的语言
            // Save the selected language
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageStorageKey)
            
            // 发送语言变化通知
            // Send language change notification
            NotificationCenter.default.post(name: .languageDidChange, object: currentLanguage)
        }
    }
    
    /// Current locale based on language setting
    @Published private(set) var currentLocale: Locale
    
    /// Bundle for language resources
    private var bundle: Bundle = .main {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// Cancellables for subscription management
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // 读取保存的语言设置，如果没有则使用系统语言
        // Read saved language setting, use system language if none
        let savedLanguageString = UserDefaults.standard.string(forKey: languageStorageKey)
        
        // 获取当前语言
        // Get current language
        let language: AppLanguage
        if let savedLanguageString = savedLanguageString,
           let savedLanguage = AppLanguage(rawValue: savedLanguageString) {
            language = savedLanguage
        } else {
            language = AppLanguage.systemLanguage()
        }
        
        // 初始化属性
        // Initialize properties
        self.currentLanguage = language
        self.currentLocale = Locale(identifier: language.rawValue)
        
        // 更新语言包
        // Update language bundle
        updateLanguageBundle(for: language)
        
        // 监听系统区域设置变化
        // Listen for system locale changes
        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let savedLanguageString = UserDefaults.standard.string(forKey: self.languageStorageKey)
                if savedLanguageString == nil {
                    let newSystemLanguage = AppLanguage.systemLanguage()
                    self.updateLanguage(newSystemLanguage)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Change app language
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: languageStorageKey)
        
        updateLocale()
        updateLanguageBundle(for: language)
        
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    /// Reset to system language
    func resetLanguage() {
        UserDefaults.standard.removeObject(forKey: languageStorageKey)
        let systemLanguage = AppLanguage.systemLanguage()
        updateLanguage(systemLanguage)
    }
    
    /// Get a localized string for the given key
    func localizedString(for key: String, comment: String) -> String {
        let result = bundle.localizedString(forKey: key, value: nil, table: nil)
        if result == key {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        return result
    }
    
    // MARK: - Private Methods
    
    /// Update language and related properties
    private func updateLanguage(_ language: AppLanguage) {
        currentLanguage = language
        updateLocale()
        updateLanguageBundle(for: language)
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    /// Update the current locale based on selected language
    private func updateLocale() {
        self.currentLocale = currentLanguage.locale
    }
    
    /// Update the language bundle for the specified language
    private func updateLanguageBundle(for language: AppLanguage) {
        if Bundle.main.localizations.contains(language.rawValue),
           let bundlePath = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let languageBundle = Bundle(path: bundlePath) {
            self.bundle = languageBundle
        } else {
            self.bundle = .main
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let languageDidChange = Notification.Name("com.easytime.keyflash.languageDidChange")
}

// MARK: - String Extension

extension String {
    /// Get localized version of this string
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self, comment: "")
    }
} 
