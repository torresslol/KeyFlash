import Foundation
import AppKit

/// 用于序列化和缓存的修饰键数据模型
/// Modifier key data model for serialization and caching
struct ModifierKeysModel: Codable, Hashable {
    let command: Bool
    let option: Bool
    let control: Bool
    let shift: Bool
    
    init(from entity: ModifierKeys) {
        self.command = entity.command
        self.option = entity.option
        self.control = entity.control
        self.shift = entity.shift
    }
    
    func toEntity() -> ModifierKeys {
        return ModifierKeys(
            command: command,
            option: option,
            control: control,
            shift: shift
        )
    }
}

/// 用于序列化和缓存的菜单项数据模型
/// Menu item data model for serialization and caching
struct MenuItemModel: Codable, Hashable {
    let title: String
    let shortcutDescription: String?
    let keyCode: Int?
    let modifiers: ModifierKeysModel?
    let menuGroup: String
    let menuPath: String
    let isSeparator: Bool
    let isSubmenuTitle: Bool
    
    init(from entity: MenuItemEntity) {
        self.title = entity.title
        self.shortcutDescription = entity.shortcutDescription
        self.keyCode = entity.keyCode
        self.modifiers = entity.modifiers.map { ModifierKeysModel(from: $0) }
        self.menuGroup = entity.menuGroup
        self.menuPath = entity.menuPath
        self.isSeparator = entity.isSeparator
        self.isSubmenuTitle = entity.isSubmenuTitle
    }
    
    func toEntity() -> MenuItemEntity {
        return MenuItemEntity(
            title: title,
            shortcutDescription: shortcutDescription,
            keyCode: keyCode,
            modifiers: modifiers?.toEntity(),
            menuGroup: menuGroup,
            menuPath: menuPath,
            isSeparator: isSeparator,
            isSubmenuTitle: isSubmenuTitle
        )
    }
}

/// 用于序列化和缓存的应用程序数据模型
/// Application data model for serialization and caching
struct ApplicationModel: Codable, Hashable {
    let name: String
    let bundleIdentifier: String
    let processIdentifier: Int
    let executablePath: String?
    let menuItems: [MenuItemModel]
    let lastRefreshTime: Date
    
    init(from entity: ApplicationEntity) {
        self.name = entity.name
        self.bundleIdentifier = entity.bundleIdentifier
        self.processIdentifier = entity.processIdentifier
        self.executablePath = entity.executablePath
        self.menuItems = entity.menuItems.map { MenuItemModel(from: $0) }
        self.lastRefreshTime = entity.lastRefreshTime
    }
    
    func toEntity() -> ApplicationEntity {
        // NSImage cannot be serialized directly, so we recreate it from the app bundle
        let icon = NSWorkspace.shared.icon(forFile: executablePath ?? "")
        
        var appEntity = ApplicationEntity(
            name: name,
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            processIdentifier: processIdentifier,
            executablePath: executablePath,
            menuItems: menuItems.map { $0.toEntity() }
        )
        appEntity.lastRefreshTime = lastRefreshTime
        
        return appEntity
    }
} 