import Foundation
import Combine
import AppKit

/// Available trigger keys for showing the panel
enum TriggerKey: String, CaseIterable, Codable {
    case command
    case control
    case option
    case function
    
    var displayName: String {
        switch self {
        case .command:
            return "Command ⌘"
        case .control:
            return "Control ⌃"
        case .option:
            return "Option ⌥"
        case .function:
            return "Function fn"
        }
    }
    
    var keyCharacter: String {
        switch self {
        case .command:
            return "⌘"
        case .control:
            return "⌃"
        case .option:
            return "⌥"
        case .function:
            return "fn"
        }
    }
    
    var modifierFlags: NSEvent.ModifierFlags {
        switch self {
        case .command:
            return .command
        case .control:
            return .control
        case .option:
            return .option
        case .function:
            return .function
        }
    }
}

/// Manager for handling trigger key settings
class TriggerKeyManager: ObservableObject {
    // MARK: - Properties
    
    /// 用于存储选择的触发键的UserDefaults键
    /// UserDefaults key for storing the selected trigger key
    private let triggerKeyStorageKey = "com.easytime.keyflash.selectedTriggerKey"
    
    /// 当前触发键
    /// Current trigger key
    @Published private(set) var currentTriggerKey: TriggerKey {
        didSet {
            UserDefaults.standard.set(currentTriggerKey.rawValue, forKey: triggerKeyStorageKey)
            NotificationCenter.default.post(name: .triggerKeyDidChange, object: nil)
        }
    }
    
    /// 单例实例
    /// Singleton instance
    static let shared = TriggerKeyManager()
    
    /// 触发键变化通知名称
    /// Trigger key change notification name
    static let triggerKeyDidChange = Notification.Name("com.easytime.keyflash.triggerKeyDidChange")
    
    // MARK: - Initialization
    
    private init() {
        // Load saved trigger key or use default
        if let savedKey = UserDefaults.standard.string(forKey: triggerKeyStorageKey),
           let triggerKey = TriggerKey(rawValue: savedKey) {
            self.currentTriggerKey = triggerKey
        } else {
            // Default to command key
            self.currentTriggerKey = .command
        }
    }
    
    // MARK: - Public Methods
    
    /// Change the trigger key
    func setTriggerKey(_ key: TriggerKey) {
        guard key != currentTriggerKey else { return }
        currentTriggerKey = key
    }
    
    /// Reset to default trigger key (Command)
    func resetTriggerKey() {
        setTriggerKey(.command)
    }
    
    /// Check if the event matches current trigger key
    func matchesTriggerKey(_ event: NSEvent) -> Bool {
        // Only check modifier flags for now
        return event.modifierFlags.contains(currentTriggerKey.modifierFlags)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let triggerKeyDidChange = Notification.Name("com.easytime.keyflash.triggerKeyDidChange")
} 