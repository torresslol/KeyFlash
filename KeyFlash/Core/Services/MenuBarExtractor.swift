import Cocoa
import ApplicationServices
import Combine
import os.log
import Accessibility

/// 菜单栏提取器，用于从应用程序提取所有菜单项及其快捷键
/// Menu bar extractor, used to extract all menu items and their shortcuts from an application
class MenuBarExtractor {
    // MARK: - Properties
    
    // 日志对象
    // Logger object
    private let logger = Logger(subsystem: "com.easytime.KeyFlash", category: "MenuBarExtractor")
    
    // 调试模式
    // Debug mode
    private let debugMode = true
    
    // 修饰键映射 - 更简洁的映射
    // Modifier key mapping - more concise mapping
    private let modifiers: [[String]] = [
        ["⌘"], // 0
        ["⇧", "⌘"], // 1
        ["⌥", "⌘"], // 2
        ["⌥", "⇧", "⌘"], // 3
        ["⌃", "⌘"], // 4
        ["⌃", "⇧", "⌘"], // 5
        ["⌃", "⌥", "⌘"], // 6
        ["⌃", "⌥", "⇧", "⌘"], // 7
        [], // 8
        ["⇧"], // 9
        ["⌥"], // 10
        ["⌥", "⇧"], // 11
        ["⌃"], // 12
        ["⌃", "⇧"], // 13
        ["⌃", "⌥"], // 14
        ["⌃", "⌥", "⇧"], // 15
    ]
    
    // 当前应用程序实体
    // Current application entity
    private var currentApplication: ApplicationEntity?
    
    // 辅助功能服务
    // Accessibility service
    private let accessibilityService: AccessibilityService
    
    // 键码映射器
    // Key code mapper
    private let keyCodeMapper = KeyCodeMapper.shared
    
    // 提取进度发布者
    // Extraction progress publisher
    private let extractionProgressSubject = PassthroughSubject<Float, Never>()
    var extractionProgressPublisher: AnyPublisher<Float, Never> {
        extractionProgressSubject.eraseToAnyPublisher()
    }
    
    // 提取完成发布者
    // Extraction completion publisher
    private let extractionCompletedSubject = PassthroughSubject<ShortcutApplicationEntity, Error>()
    var extractionCompletedPublisher: AnyPublisher<ShortcutApplicationEntity, Error> {
        extractionCompletedSubject.eraseToAnyPublisher()
    }
    
    // 取消标志
    // Cancellation flag
    private var isCancelled = false
    
    // 正在进行的任务
    // Task currently in progress
    private var extractionWorkItem: DispatchWorkItem?
    
    // MARK: - Initialization
    
    init(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
    }
    
    // MARK: - Public Methods
    
    /// 从当前活动的应用程序提取菜单栏快捷键
    /// Extracts menu bar shortcuts from the currently active application
    func extractShortcutsFromCurrentApplication() {
        // 取消之前的任务
        // Cancel previous task
//        cancelExtraction()
        
        // 不再检查辅助功能权限，由AppDelegate统一处理
        // No longer check accessibility permissions, handled centrally by AppDelegate
        
        // 在主线程获取当前活动的应用程序（这部分必须在主线程进行）
        // Get the currently active application on the main thread (this part must be on the main thread)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let runningApp = self.accessibilityService.getCurrentFocusedApplication(),
                  let application = ApplicationEntity.from(application: runningApp) else {
                self.logDebug("Unable to get the currently active application") // Unable to get the currently active application
                self.extractionCompletedSubject.send(completion: Subscribers.Completion.failure(MenuBarExtractionError.applicationNotFound))
                return
            }
            
            self.logDebug("Starting to extract shortcuts for application: \(application.name) (\(application.bundleIdentifier))") // Starting to extract shortcuts for application: ...
            self.currentApplication = application
            self.isCancelled = false
            
            // 创建工作项
            // Create work item
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isCancelled else { return }
                self.extractMenuItems(for: application)
            }
            
            self.extractionWorkItem = workItem
            
            // 在主线程执行提取，因为菜单操作必须在主线程进行
            // Execute extraction on the main thread, as menu operations must be on the main thread
            DispatchQueue.main.async(execute: workItem)
        }
    }
    
    /// 取消当前的提取操作
    /// Cancels the current extraction operation
    func cancelExtraction() {
        logDebug("Canceling extraction operation") // Canceling extraction operation
        isCancelled = true
        extractionWorkItem?.cancel()
        extractionWorkItem = nil
    }
    
    // MARK: - Private Methods
    
    /// 从应用程序提取快捷键
    /// Extracts shortcuts from the application
    private func extractMenuItems(for application: ApplicationEntity) {
        let pid = application.processIdentifier
        let axApp = AXUIElementCreateApplication(pid_t(pid))
        
        // 获取应用程序的菜单栏
        // Get the application's menu bar
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &value)
        
        if result != .success {
            extractionCompletedSubject.send(completion: Subscribers.Completion.failure(MenuBarExtractionError.menuBarNotFound))
            return
        }
        
        let menuBar = value as! AXUIElement
        guard let menuBarItems = getValue(of: menuBar, attribute: kAXChildrenAttribute, as: [AXUIElement].self) else {
            extractionCompletedSubject.send(completion: Subscribers.Completion.failure(MenuBarExtractionError.menuItemsNotFound))
            return
        }
        
        var allMenuItems: [MenuItemEntity] = []
        let totalMenuCount = menuBarItems.count
        var processedMenuCount = 0
        
        // 预先分配容量以避免频繁的数组扩容
        // Pre-allocate capacity to avoid frequent array resizing
        allMenuItems.reserveCapacity(totalMenuCount * 10)
        
        for menuBarItem in menuBarItems {
            guard !isCancelled else {
                extractionCompletedSubject.send(completion: Subscribers.Completion.failure(MenuBarExtractionError.extractionCancelled))
                return
            }
            
            // 获取菜单组标题
            // Get menu group title
            guard let groupTitle = getValue(of: menuBarItem, attribute: kAXTitleAttribute, as: String.self) else {
                processedMenuCount += 1
                continue
            }
            
            // 排除Apple菜单
            // Exclude Apple menu
            if groupTitle == "Apple" {
                processedMenuCount += 1
                continue
            }
            
            // 添加菜单组标题
            // Add menu group title
            allMenuItems.append(MenuItemEntity(
                title: groupTitle,
                menuGroup: groupTitle,
                menuPath: groupTitle,
                isSubmenuTitle: true
            ))
            
            // 获取菜单组的子菜单
            // Get submenus of the menu group
            guard let menus = getValue(of: menuBarItem, attribute: kAXChildrenAttribute, as: [AXUIElement].self) else {
                processedMenuCount += 1
                continue
            }
            
            // 处理每个菜单
            // Process each menu
            for menu in menus {
                guard let menuItems = getValue(of: menu, attribute: kAXChildrenAttribute, as: [AXUIElement].self) else {
                    continue
                }
                
                for menuItem in menuItems {
                    if let item = getMenuItemEntity(from: menuItem, menuGroup: groupTitle, parentPath: groupTitle) {
                        allMenuItems.append(item)
                    }
                }
            }
            
            processedMenuCount += 1
            let progress = Float(processedMenuCount) / Float(totalMenuCount)
            extractionProgressSubject.send(progress)
        }
        
        // 更新应用程序实体的菜单项
        // Update the menu items of the application entity
        var updatedApp = application
        updatedApp.menuItems = allMenuItems
        updatedApp.lastRefreshTime = Date()
        
        // 通知观察者提取完成
        // Notify observers that extraction is complete
        extractionCompletedSubject.send(updatedApp)
        currentApplication = nil
    }
    
    /// 从菜单项获取实体
    /// Gets the entity from a menu item
    private func getMenuItemEntity(from menuItem: AXUIElement, menuGroup: String, parentPath: String) -> MenuItemEntity? {
        // 获取标题
        // Get title
        guard let title = getValue(of: menuItem, attribute: kAXTitleAttribute, as: String.self) else {
            return nil
        }
        
        // 检查是否为分隔符
        // Check if it is a separator
        if title == "separator" || title.isEmpty {
            return MenuItemEntity(
                title: title,
                menuGroup: menuGroup,
                menuPath: "\(parentPath)/separator",
                isSeparator: true
            )
        }
        
        let menuPath = "\(parentPath)/\(title)"
        
        // 批量获取所有快捷键相关属性
        // Bulk fetch all shortcut-related attributes
        var attributes: [String: AnyObject] = [:]
        let attributeNames = [
            kAXMenuItemCmdVirtualKeyAttribute, // 虚拟键码（特殊键） // Virtual key code (special keys)
            kAXMenuItemCmdCharAttribute,       // 字符（普通键） // Character (normal keys)
            kAXMenuItemCmdModifiersAttribute   // 修饰键 // Modifier keys
        ]
        
        for attrName in attributeNames {
            var value: AnyObject?
            if AXUIElementCopyAttributeValue(menuItem, attrName as CFString, &value) == .success {
                attributes[attrName as String] = value
            }
        }
        
        // 初始化快捷键相关变量
        // Initialize shortcut-related variables
        var keyCodeValue: Int?
        var modifiersValue: ModifierKeys?
        var shortcutDescription: String?
        
        // 获取修饰键值（如果有）
        // Get modifier value (if any)
        let modifiers = attributes[kAXMenuItemCmdModifiersAttribute] as? Int
        modifiersValue = modifiers.map(createModifierKeysFromValue)
        
        // 优先使用虚拟键码（用于特殊键，如F1-F12、方向键等）
        // Prioritize using virtual key codes (for special keys like F1-F12, arrow keys, etc.)
        if let virtualKey = attributes[kAXMenuItemCmdVirtualKeyAttribute] as? Int {
            keyCodeValue = virtualKey
            shortcutDescription = modifiers.map { keyCodeMapper.symbolForShortcutWithVirtualKey(virtualKey, modifiers: $0) }
                ?? keyCodeMapper.symbolForShortcutWithVirtualKey(virtualKey, modifiers: 0)
        }
        
        // 如果虚拟键码解析失败或返回了未识别的键码（如 ?128?），尝试使用 cmdChar 作为兜底方案
        // If virtual key code parsing fails or returns an unrecognized key code (e.g., ?128?), try using cmdChar as a fallback
        if shortcutDescription == nil || shortcutDescription?.contains("?") == true,
           let cmdChar = attributes[kAXMenuItemCmdCharAttribute] as? String,
           !cmdChar.isEmpty {
            if let mod = modifiers, mod >= 0 && mod < self.modifiers.count {
                let modSymbols = self.modifiers[mod]
                shortcutDescription = (modSymbols + [cmdChar]).joined()
            } else {
                shortcutDescription = modifiers.map { keyCodeMapper.symbolForShortcut(character: cmdChar, modifiers: $0) }
                    ?? cmdChar
            }
            
            if let asciiValue = cmdChar.first?.asciiValue {
                keyCodeValue = Int(asciiValue)
            }
        }
        
        // 创建和返回菜单项实体
        // Create and return the menu item entity
        return MenuItemEntity(
            title: title,
            shortcutDescription: shortcutDescription,
            keyCode: keyCodeValue,
            modifiers: modifiersValue,
            menuGroup: menuGroup,
            menuPath: menuPath
        )
    }
    
    /// 从修饰键值创建ModifierKeys对象
    /// Creates a ModifierKeys object from a modifier value
    private func createModifierKeysFromValue(_ value: Int) -> ModifierKeys {
        var hasCommand = false
        var hasOption = false
        var hasControl = false
        var hasShift = false
        
        // 使用预定义的修饰键数组
        // Use the predefined modifier key array
        if value >= 0 && value < modifiers.count {
            let modSymbols = modifiers[value]
            hasCommand = modSymbols.contains("⌘")
            hasOption = modSymbols.contains("⌥")
            hasControl = modSymbols.contains("⌃")
            hasShift = modSymbols.contains("⇧")
        } else {
            // 手动解析修饰键位
            // Manually parse modifier key bits
            hasCommand = (value & 0x08) != 0 || (value & 0x100) != 0
            hasShift = (value & 0x02) != 0
            hasOption = (value & 0x04) != 0
            hasControl = (value & 0x01) != 0
        }
        
        return ModifierKeys(
            command: hasCommand,
            option: hasOption,
            control: hasControl,
            shift: hasShift
        )
    }
    
    /// 获取UI元素的属性值
    /// Gets the attribute value of a UI element
    func getValue<T>(of element: AXUIElement, attribute: String, as type: T.Type) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        if result == .success, let typedValue = value as? T {
            return typedValue
        }
        
        return nil as T?
    }
    
    /// 记录调试日志
    /// Logs a debug message
    private func logDebug(_ message: String) {
        if debugMode {
            logger.debug("\(message)")
            print("[MenuBarExtractor] \(message)")
        }
    }
    
    /// 获取AXError的可读描述
    /// Gets a readable description of an AXError
    private func axErrorDescription(_ error: AXError) -> String {
        switch error {
        case .success:
            return "Success"
        case .failure:
            return "General failure"
        case .illegalArgument:
            return "Illegal argument"
        case .invalidUIElement:
            return "Invalid UI element"
        case .invalidUIElementObserver:
            return "Invalid UI element observer"
        case .cannotComplete:
            return "Cannot complete operation"
        case .attributeUnsupported:
            return "Attribute unsupported"
        case .actionUnsupported:
            return "Action unsupported"
        case .notificationUnsupported:
            return "Notification unsupported"
        case .notImplemented:
            return "Not implemented"
        case .notificationAlreadyRegistered:
            return "Notification already registered"
        case .notificationNotRegistered:
            return "Notification not registered"
        case .apiDisabled:
            return "API disabled (Accessibility permission not granted)"
        case .noValue:
            return "No value"
        case .parameterizedAttributeUnsupported:
            return "Parameterized attribute unsupported"
        case .notEnoughPrecision:
            return "Not enough precision"
        default:
            return "Unknown error (code: \(error.rawValue))"
        }
    }
}

// MARK: - Errors

enum MenuBarExtractionError: Error {
    case noAccessibilityPermission
    case applicationNotFound
    case menuBarNotFound
    case menuItemsNotFound
    case extractionCancelled
    
    var localizedDescription: String {
        switch self {
        case .noAccessibilityPermission:
            return "Accessibility permission not granted. Please authorize in System Preferences."
        case .applicationNotFound:
            return "Unable to get the current active application."
        case .menuBarNotFound:
            return "Unable to get the application's menu bar."
        case .menuItemsNotFound:
            return "Unable to get menu items from the menu bar."
        case .extractionCancelled:
            return "Menu extraction operation cancelled."
        }
    }
}
