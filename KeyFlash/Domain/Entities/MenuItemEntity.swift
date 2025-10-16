import Foundation
import AppKit

/// 表示菜单项的实体
/// Entity representing a menu item
struct MenuItemEntity: Identifiable, Hashable {
    let id = UUID()
    
    // 菜单项的标题
    // Title of the menu item
    let title: String
    
    // 菜单项的快捷键描述（如 "⌘C"）
    // Shortcut description for the menu item (e.g., "⌘C")
    let shortcutDescription: String?
    
    // 菜单项的键码组合（用于映射）
    // Key code combination for the menu item (for mapping)
    let keyCode: Int?
    
    // 快捷键的修饰键
    // Modifier keys for the shortcut
    let modifiers: ModifierKeys?
    
    // 所属的菜单组（如"File"、"Edit"等）
    // The menu group it belongs to (e.g., "File", "Edit")
    let menuGroup: String
    
    // 菜单层级路径（如 "File > New > Project"）
    // Menu hierarchy path (e.g., "File > New > Project")
    let menuPath: String
    
    // 是否是分隔符
    // Is it a separator
    let isSeparator: Bool
    
    // 是否是子菜单标题
    // Is it a submenu title
    let isSubmenuTitle: Bool
    
    // MARK: - Initialization
    
    init(
        title: String,
        shortcutDescription: String? = nil,
        keyCode: Int? = nil,
        modifiers: ModifierKeys? = nil,
        menuGroup: String,
        menuPath: String,
        isSeparator: Bool = false,
        isSubmenuTitle: Bool = false
    ) {
        self.title = title
        self.shortcutDescription = shortcutDescription
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.menuGroup = menuGroup
        self.menuPath = menuPath
        self.isSeparator = isSeparator
        self.isSubmenuTitle = isSubmenuTitle
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(menuPath)
    }
    
    static func == (lhs: MenuItemEntity, rhs: MenuItemEntity) -> Bool {
        lhs.id == rhs.id
    }
}

/// 表示快捷键的修饰键组合
/// Represents the combination of modifier keys for a shortcut
struct ModifierKeys: Hashable {
    let command: Bool
    let option: Bool
    let control: Bool
    let shift: Bool
    
    init(command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }
    
    /// 从NSEvent修饰键标志创建
    /// Create from NSEvent modifier flags
    static func from(flags: NSEvent.ModifierFlags) -> ModifierKeys {
        return ModifierKeys(
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )
    }
    
    /// 获取修饰键的字符串表示（如"⌘⌥⇧"）
    /// Get the string representation of modifier keys (e.g., "⌘⌥⇧")
    var stringRepresentation: String {
        var result = ""
        if control { result += "⌃" }
        if option { result += "⌥" }
        if shift { result += "⇧" }
        if command { result += "⌘" }
        return result
    }
} 
