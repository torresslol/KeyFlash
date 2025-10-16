import Foundation
import Combine

/// Manager for app-wide settings
class AppSettingsManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = AppSettingsManager()
    
    // MARK: - Properties
    
    @Published private(set) var currentTheme: ThemeMode {
        didSet {
            if oldValue != currentTheme {
                themeManager.changeTheme(to: currentTheme)
            }
        }
    }
    
    @Published private(set) var currentLanguage: AppLanguage {
        didSet {
            if oldValue != currentLanguage {
                localizationManager.setLanguage(currentLanguage)
            }
        }
    }
    
    // MARK: - Managers
    
    private let themeManager = ThemeManager.shared
    private let localizationManager = LocalizationManager.shared
    
    // MARK: - Cancellables
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Initialize with current values from individual managers
        currentTheme = themeManager.currentThemeMode
        currentLanguage = localizationManager.currentLanguage
        
        // Set up subscriptions to keep in sync with managers
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Set the app theme
    func setTheme(_ theme: ThemeMode) {
        currentTheme = theme
    }
    
    /// Set the app language
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    /// Reset to system defaults
    func resetToDefaults() {
        resetTheme()
        resetLanguage()
    }
    
    // MARK: - Private Methods
    
    /// Reset theme to system default
    private func resetTheme() {
        themeManager.resetTheme()
        currentTheme = themeManager.currentThemeMode
    }
    
    /// Reset language to system default
    private func resetLanguage() {
        localizationManager.resetLanguage()
        currentLanguage = localizationManager.currentLanguage
    }
    
    /// Set up subscriptions to keep in sync with managers
    private func setupSubscriptions() {
        // Subscribe to theme changes
        NotificationCenter.default.publisher(for: .themeDidChange)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.currentTheme = self.themeManager.currentThemeMode
            }
            .store(in: &cancellables)
        
        // Subscribe to language changes
        NotificationCenter.default.publisher(for: .languageDidChange)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.currentLanguage = self.localizationManager.currentLanguage
            }
            .store(in: &cancellables)
    }
} 