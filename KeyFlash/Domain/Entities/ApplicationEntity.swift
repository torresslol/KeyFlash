import Foundation
import AppKit

/// 表示应用程序的实体
/// Entity representing an application
struct ApplicationEntity: Identifiable {
    let id = UUID()
    
    // 应用程序的名称
    // Name of the application
    let name: String
    
    // 应用程序的捆绑包标识符
    // Bundle identifier of the application
    let bundleIdentifier: String
    
    // 应用程序的图标
    // Icon of the application
    let icon: NSImage
    
    // 应用程序的进程ID
    // Process ID of the application
    let processIdentifier: Int
    
    // 应用程序的执行路径
    // Executable path of the application
    let executablePath: String?
    
    // 应用程序的菜单项集合
    // Collection of menu items for the application
    var menuItems: [MenuItemEntity] = []
    
    // 上次刷新时间
    // Last refresh time
    var lastRefreshTime: Date = Date()
    
    // MARK: - Initialization
    
    init(
        name: String,
        bundleIdentifier: String,
        icon: NSImage,
        processIdentifier: Int,
        executablePath: String? = nil,
        menuItems: [MenuItemEntity] = []
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.processIdentifier = processIdentifier
        self.executablePath = executablePath
        self.menuItems = menuItems
        self.lastRefreshTime = Date()
    }
    
    // 从NSRunningApplication创建ApplicationEntity
    // Create ApplicationEntity from NSRunningApplication
    static func from(application: NSRunningApplication) -> ApplicationEntity? {
        guard let bundleIdentifier = application.bundleIdentifier,
              let icon = application.icon else {
            return nil
        }
        
        return ApplicationEntity(
            name: application.localizedName ?? "Unknown",
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            processIdentifier: Int(application.processIdentifier),
            executablePath: application.executableURL?.path
        )
    }
}

// 为UI添加类型别名，使用现有的ApplicationEntity
// Add type alias for UI, using existing ApplicationEntity
typealias ShortcutApplicationEntity = ApplicationEntity

// 为菜单项添加别名，使用现有的MenuItemEntity
// Add alias for menu items, using existing MenuItemEntity
typealias ShortcutMenuItemEntity = MenuItemEntity

// 扩展ApplicationEntity，添加转换方法
// Extend ApplicationEntity, add conversion method
extension ApplicationEntity {
    // 转换方法，用于从内部应用实体创建UI展示用的实体
    // Conversion method, used to create UI display entity from internal application entity
    static func asShortcutEntity(from application: ApplicationEntity) -> ShortcutApplicationEntity {
        return application
    }
    
    // 获取应用程序捆绑包路径（用于UI）
    // Get application bundle path (for UI)
    var bundlePath: String {
        return executablePath ?? "/Applications"
    }
} 