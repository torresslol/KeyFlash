import AppKit
import Combine
import SwiftUI

/// Theme options available in the app
enum ThemeMode: String, CaseIterable {
    case light
    case dark
    
    var displayName: String {
        switch self {
        case .light:
            return "theme_light".localized
        case .dark:
            return "theme_dark".localized
        }
    }
}

/// Notification names for theme changes
extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}

/// Manages app-wide theming
class ThemeManager: ObservableObject {
    // MARK: - Properties
    
    static let shared = ThemeManager()
    
    /// UserDefaults keys
    private let themeUserDefaultsKey = "app_theme"
    
    /// Published properties for SwiftUI updates
    @Published var currentThemeMode: ThemeMode = .light
    @Published var isDarkMode: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        // 简单初始化，默认使用浅色主题
        // Simple initialization, defaults to light theme
        // 从 UserDefaults 加载保存的主题（如果有）
        // Load saved theme from UserDefaults (if any)
        if let savedThemeString = UserDefaults.standard.string(forKey: themeUserDefaultsKey),
           let savedTheme = ThemeMode(rawValue: savedThemeString) {
            self.currentThemeMode = savedTheme
            self.isDarkMode = savedTheme == .dark
        }
    }
    
    // MARK: - Public Methods
    
    /// Changes the app's theme mode
    func changeTheme(to themeMode: ThemeMode) {
        self.currentThemeMode = themeMode
        self.isDarkMode = themeMode == .dark
        
        // Save to UserDefaults
        UserDefaults.standard.set(themeMode.rawValue, forKey: themeUserDefaultsKey)
        
        // Notify about the change
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }
    
    /// Resets to default light theme
    func resetTheme() {
        // 重置为浅色主题
        // Reset to light theme
        self.currentThemeMode = .light
        self.isDarkMode = false
        
        // 移除存储的设置
        // Remove stored settings
        UserDefaults.standard.removeObject(forKey: themeUserDefaultsKey)
        
        // 通知主题变化
        // Notify about the theme change
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }
    
    // MARK: - Theme Colors
    
    // Background colors
    var backgroundColor: Color {
        isDarkMode ? Color(hex: "1A1B26") : Color(hex: "F5F7FA")
    }
    
    var backgroundSecondaryColor: Color {
        isDarkMode ? Color(hex: "24283B") : Color(hex: "E4E9F2")
    }
    
    var backgroundTertiaryColor: Color {
        isDarkMode ? Color(hex: "2D3147").opacity(0.8) : Color(hex: "CFD6E4").opacity(0.9)
    }
    
    // Accent colors
    var accentColor: Color {
        Color(hex: "7C84A6")
    }
    
    var accentSecondaryColor: Color {
        isDarkMode ? Color(hex: "414868").opacity(0.5) : Color(hex: "CFD6E4").opacity(0.9)
    }
    
    var accentTertiaryColor: Color {
        isDarkMode ? Color(hex: "414868").opacity(0.3) : Color(hex: "D8DEE9").opacity(0.5)
    }
    
    // Text colors
    var textPrimaryColor: Color {
        isDarkMode ? Color.white : Color.black
    }
    
    var textSecondaryColor: Color {
        isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.7)
    }
    
    var textTertiaryColor: Color {
        isDarkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.4)
    }
    
    // Selected text colors
    var selectedTextColor: Color {
        isDarkMode ? Color(hex: "1A1B26") : Color.white
    }
    
    // Search bar colors
    var searchTextColor: Color {
        isDarkMode ? textPrimaryColor.opacity(0.9) : textPrimaryColor
    }
    
    var searchPlaceholderColor: Color {
        // 使搜索栏占位符颜色与未选中的分类标签颜色一致
        // Make search bar placeholder color consistent with unselected category label color
        textSecondaryColor
    }
    
    var searchIconColor: Color {
        // 图标颜色也与占位符保持一致
        // Icon color also consistent with placeholder
        textSecondaryColor
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
