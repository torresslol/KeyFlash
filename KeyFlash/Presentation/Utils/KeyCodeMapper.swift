import Foundation
import AppKit
import Carbon.HIToolbox.Events

/// 键码映射器，负责将键码映射到可读字符
/// Key code mapper, responsible for mapping key codes to readable characters
class KeyCodeMapper {
    // MARK: - Properties
    
    // 单例实例
    // Singleton instance
    static let shared = KeyCodeMapper()
    
    // 键码到字符的映射表
    // Key code to character mapping table
    private(set) var keyCodeToCharacter: [Int: String] = [
        0: "a",
        1: "s",
        2: "d",
        3: "f",
        4: "h",
        5: "g",
        6: "z",
        7: "x",
        8: "c",
        9: "v",
        11: "b",
        12: "q",
        13: "w",
        14: "e",
        15: "r",
        16: "y",
        17: "t",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "o",
        32: "u",
        33: "[",
        34: "i",
        35: "p",
        37: "l",
        38: "j",
        39: "'",
        40: "k",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "n",
        46: "m",
        47: ".",
        50: "`",
        65: ".",
        67: "*",
        69: "+",
        71: "Clear",
        75: "/",
        76: "Enter",
        78: "-",
        81: "=",
        82: "0",
        83: "1",
        84: "2",
        85: "3",
        86: "4",
        87: "5",
        88: "6",
        89: "7",
        91: "8",
        92: "9",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "Delete",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
        36: "Return",
        48: "Tab",
        49: "Space",
        51: "⌫",
        53: "Escape",
        55: "Command",
        56: "Shift",
        57: "Caps Lock",
        58: "Option",
        59: "Control",
        60: "Right Shift",
        61: "Right Option",
        62: "Right Control",
        63: "Function",
    ]
    
    // 功能键的特殊映射
    // Special mapping for function keys
    private(set) var functionKeyMapping: [Int: String] = [
        122: "F1",
        120: "F2",
        99: "F3",
        118: "F4",
        96: "F5",
        97: "F6",
        98: "F7",
        100: "F8",
        101: "F9",
        109: "F10",
        103: "F11",
        111: "F12",
        105: "F13",
        107: "F14",
        113: "F15",
        106: "F16",
        64: "F17",
        79: "F18",
        80: "F19",
        90: "F20",
    ]
    
    // 其他特殊键的映射
    // Mapping for other special keys
    private(set) var specialKeyMapping: [Int: String] = [
        36: "↩",    // Return
        48: "⇥",    // Tab
        49: "␣",    // Space
        51: "⌫",    // Delete/Backspace
        53: "⎋",    // Escape
        76: "⌤",    // Enter (Keypad)
        114: "?⃝",   // Help
        115: "↖",   // Home
        116: "⇞",   // Page Up
        117: "⌦",   // Forward Delete
        119: "↘",   // End
        121: "⇟",   // Page Down
        123: "←",   // Left Arrow
        124: "→",   // Right Arrow
        125: "↓",   // Down Arrow
        126: "↑",   // Up Arrow
    ]
    
    // Carbon 虚拟键码常量
    // Carbon virtual key code constants
    private let carbonKeyCodes: [Int: String] = [
        kVK_ANSI_A: "A",
        kVK_ANSI_S: "S",
        kVK_ANSI_D: "D",
        kVK_ANSI_F: "F",
        kVK_ANSI_H: "H",
        kVK_ANSI_G: "G",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_X: "X",
        kVK_ANSI_C: "C",
        kVK_ANSI_V: "V",
        kVK_ANSI_B: "B",
        kVK_ANSI_Q: "Q",
        kVK_ANSI_W: "W",
        kVK_ANSI_E: "E",
        kVK_ANSI_R: "R",
        kVK_ANSI_Y: "Y",
        kVK_ANSI_T: "T",
        kVK_ANSI_1: "1",
        kVK_ANSI_2: "2",
        kVK_ANSI_3: "3",
        kVK_ANSI_4: "4",
        kVK_ANSI_6: "6",
        kVK_ANSI_5: "5",
        kVK_ANSI_Equal: "=",
        kVK_ANSI_9: "9",
        kVK_ANSI_7: "7",
        kVK_ANSI_Minus: "-",
        kVK_ANSI_8: "8",
        kVK_ANSI_0: "0",
        kVK_ANSI_RightBracket: "]",
        kVK_ANSI_O: "O",
        kVK_ANSI_U: "U",
        kVK_ANSI_LeftBracket: "[",
        kVK_ANSI_I: "I",
        kVK_ANSI_P: "P",
        kVK_ANSI_L: "L",
        kVK_ANSI_J: "J",
        kVK_ANSI_Quote: "'",
        kVK_ANSI_K: "K",
        kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Backslash: "\\",
        kVK_ANSI_Comma: ",",
        kVK_ANSI_Slash: "/",
        kVK_ANSI_N: "N",
        kVK_ANSI_M: "M",
        kVK_ANSI_Period: ".",
        kVK_ANSI_Grave: "`",
        kVK_ANSI_KeypadDecimal: ".",
        kVK_ANSI_KeypadMultiply: "*",
        kVK_ANSI_KeypadPlus: "+",
        kVK_ANSI_KeypadClear: "Clear",
        kVK_ANSI_KeypadDivide: "/",
        kVK_ANSI_KeypadEnter: "⌤",
        kVK_ANSI_KeypadMinus: "-",
        kVK_ANSI_KeypadEquals: "=",
        kVK_ANSI_Keypad0: "0",
        kVK_ANSI_Keypad1: "1",
        kVK_ANSI_Keypad2: "2",
        kVK_ANSI_Keypad3: "3",
        kVK_ANSI_Keypad4: "4",
        kVK_ANSI_Keypad5: "5",
        kVK_ANSI_Keypad6: "6",
        kVK_ANSI_Keypad7: "7",
        kVK_ANSI_Keypad8: "8",
        kVK_ANSI_Keypad9: "9",
        kVK_Return: "↩",
        kVK_Tab: "⇥",
        kVK_Space: "␣",
        kVK_Delete: "⌫",
        kVK_Escape: "⎋",
        kVK_Command: "⌘",
        kVK_Shift: "⇧",
        kVK_CapsLock: "⇪",
        kVK_Option: "⌥",
        kVK_Control: "⌃",
        kVK_RightShift: "⇧",
        kVK_RightOption: "⌥",
        kVK_RightControl: "⌃",
        kVK_Function: "Fn",
        kVK_F5: "F5",
        kVK_F6: "F6",
        kVK_F7: "F7",
        kVK_F3: "F3",
        kVK_F8: "F8",
        kVK_F9: "F9",
        kVK_F11: "F11",
        kVK_F13: "F13",
        kVK_F16: "F16",
        kVK_F14: "F14",
        kVK_F10: "F10",
        kVK_F12: "F12",
        kVK_F15: "F15",
        kVK_Help: "Help",
        kVK_Home: "↖",
        kVK_PageUp: "⇞",
        kVK_ForwardDelete: "⌦",
        kVK_F4: "F4",
        kVK_End: "↘",
        kVK_F2: "F2",
        kVK_PageDown: "⇟",
        kVK_F1: "F1",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_DownArrow: "↓",
        kVK_UpArrow: "↑",
    ]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 将键码转换为可读字符表示
    /// Converts key code to readable character representation
    /// - Parameters:
    ///   - keyCode: 键码 // Key code
    ///   - useSymbols: 是否使用符号表示特殊键 // Whether to use symbols for special keys
    /// - Returns: 可读字符表示 // Readable character representation
    func characterForKeyCode(_ keyCode: Int, useSymbols: Bool = true) -> String {
        if useSymbols, let specialChar = specialKeyMapping[keyCode] {
            return specialChar
        } else if let functionKey = functionKeyMapping[keyCode] {
            return functionKey
        } else if let character = keyCodeToCharacter[keyCode] {
            return character
        } else if let carbonKeyName = carbonKeyCodes[keyCode] {
            // 使用Carbon键码常量
            // Use Carbon key code constants
            return carbonKeyName
        } else {
            return "?\(keyCode)?"
        }
    }
    
    /// 将修饰键标志转换为字符表示
    /// Converts modifier flags to character representation
    /// - Parameter flags: 修饰键标志 // Modifier flags
    /// - Returns: 修饰键字符数组 // Array of modifier key characters
    func modifiersFromFlags(_ flags: NSEvent.ModifierFlags) -> [String] {
        var modifiers: [String] = []
        
        if flags.contains(.control) {
            modifiers.append("⌃")
        }
        
        if flags.contains(.option) {
            modifiers.append("⌥")
        }
        
        if flags.contains(.shift) {
            modifiers.append("⇧")
        }
        
        if flags.contains(.command) {
            modifiers.append("⌘")
        }
        
        return modifiers
    }
    
    /// 将修饰键标志和键码转换为完整的快捷键表示
    /// Converts modifier flags and key code to a full shortcut representation
    /// - Parameters:
    ///   - keyCode: 键码 // Key code
    ///   - modifierFlags: 修饰键标志 // Modifier flags
    /// - Returns: 完整的快捷键表示 // Full shortcut representation
    func stringForKeyCodeAndModifiers(keyCode: Int, modifierFlags: NSEvent.ModifierFlags) -> String {
        let modifierString = modifiersFromFlags(modifierFlags).joined()
        let keyString = characterForKeyCode(keyCode)
        
        return "\(modifierString)\(keyString)"
    }
    
    /// 为菜单项快捷键生成符号表示
    /// Generates symbol representation for menu item shortcuts
    /// - Parameters:
    ///   - character: 快捷键字符 // Shortcut character
    ///   - modifiers: 修饰键值（整数）// Modifier value (integer)
    /// - Returns: 快捷键的符号表示 // Symbol representation of the shortcut
    func symbolForShortcut(character: String, modifiers: Int) -> String {
        // 转换修饰键整数值为字符表示
        // Convert modifier integer value to character representation
        var modifierSymbols: [String] = []
        
        // 根据索引获取修饰键符号
        // Get modifier symbols based on index
        if modifiers >= 0 && modifiers < 16 {
            // 使用预定义的修饰键数组
            // Use predefined modifier key array
            let modifierMap: [[String]] = [
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
            modifierSymbols = modifierMap[modifiers]
        } else {
            // 备用方法：手动解析修饰键位
            // Fallback method: manually parse modifier key bits
            if (modifiers & 0x08) != 0 || (modifiers & 0x100) != 0 {
                modifierSymbols.append("⌘")
            }
            if (modifiers & 0x02) != 0 {
                modifierSymbols.append("⇧")
            }
            if (modifiers & 0x04) != 0 {
                modifierSymbols.append("⌥")
            }
            if (modifiers & 0x01) != 0 {
                modifierSymbols.append("⌃")
            }
        }
        
        // 尝试使用特殊键映射
        // Try using special key mapping
        var charSymbol = character.uppercased()
        if character.count == 1, let asciiValue = character.first?.asciiValue {
            let keyCode = Int(asciiValue)
            if let specialChar = specialKeyMapping[keyCode] {
                charSymbol = specialChar
            }
        }
        
        return modifierSymbols.joined() + charSymbol
    }
    
    /// 将虚拟键码和修饰键生成完整的快捷键表示
    /// Generates full shortcut representation from virtual key code and modifiers
    /// - Parameters:
    ///   - virtualKeyCode: 虚拟键码 // Virtual key code
    ///   - modifiers: 修饰键整数值 // Modifier integer value
    /// - Returns: 完整的快捷键表示 // Full shortcut representation
    func symbolForShortcutWithVirtualKey(_ virtualKeyCode: Int, modifiers: Int) -> String {
        
        // 获取修饰键符号
        // Get modifier symbols
        let modifierSymbols = symbolsForModifiers(modifiers)
        
        // 获取键符号
        // Get key symbol
        let keySymbol = symbolForVirtualKey(virtualKeyCode)
        
        // 组合并返回
        // Combine and return
        let shortcutSymbol = modifierSymbols + keySymbol
        return shortcutSymbol
    }
    
    /// 获取虚拟键码的符号表示
    /// Gets the symbol representation for a virtual key code
    /// - Parameter virtualKeyCode: 虚拟键码 // Virtual key code
    /// - Returns: 符号表示 // Symbol representation
    func symbolForVirtualKey(_ virtualKeyCode: Int) -> String {
        // 直接查找Carbon常量映射
        // Directly look up Carbon constant mapping
        if let carbonKeySymbol = carbonKeyCodes[virtualKeyCode] {
            return carbonKeySymbol
        }
        
        // 从特殊键映射或基本键码映射中获取
        // Get from special key mapping or basic key code mapping
        if let symbol = specialKeyMapping[virtualKeyCode] {
            return symbol
        } else if let functionKey = functionKeyMapping[virtualKeyCode] {
            return functionKey
        } else if let character = keyCodeToCharacter[virtualKeyCode] {
            return character.uppercased()
        } else {
            // 尝试用UCKeyTranslate获取字符
            // Try to get character using UCKeyTranslate
            let keyChar = getStringFromVirtualKeyCode(virtualKeyCode)
            if !keyChar.isEmpty {
                return keyChar
            }
            
            return "?\(virtualKeyCode)?" // 未知键码 // Unknown key code
        }
    }
    
    /// 获取修饰键符号的字符串表示
    /// Gets the string representation of modifier symbols
    /// - Parameter modifiers: 修饰键整数值 // Modifier integer value
    /// - Returns: 修饰键的符号表示 // Symbol representation of modifiers
    func symbolsForModifiers(_ modifiers: Int) -> String {
        
        // 使用预定义的修饰键映射数组
        // Use predefined modifier key mapping array
        if modifiers >= 0 && modifiers < 16 {
            // 修饰键映射表，索引对应不同的组合
            // Modifier key mapping table, index corresponds to different combinations
            let modifierMap: [[String]] = [
                ["⌘"],                 // 0
                ["⇧", "⌘"],           // 1
                ["⌥", "⌘"],           // 2
                ["⌥", "⇧", "⌘"],      // 3
                ["⌃", "⌘"],           // 4
                ["⌃", "⇧", "⌘"],      // 5
                ["⌃", "⌥", "⌘"],      // 6
                ["⌃", "⌥", "⇧", "⌘"], // 7
                [],                    // 8
                ["⇧"],                 // 9
                ["⌥"],                 // 10
                ["⌥", "⇧"],           // 11
                ["⌃"],                 // 12
                ["⌃", "⇧"],           // 13
                ["⌃", "⌥"],           // 14
                ["⌃", "⌥", "⇧"],      // 15
            ]
            
            let result = modifierMap[modifiers].joined()
            return result
        }
        
        // 备用方法：手动解析修饰键位（如果不在映射范围内）
        // Fallback method: manually parse modifier key bits (if outside mapping range)
        var symbols: [String] = []
        
        if (modifiers & Int(NSEvent.ModifierFlags.command.rawValue)) != 0 {
            symbols.append("⌘")
        }
        if (modifiers & Int(NSEvent.ModifierFlags.shift.rawValue)) != 0 {
            symbols.append("⇧")
        }
        if (modifiers & Int(NSEvent.ModifierFlags.option.rawValue)) != 0 {
            symbols.append("⌥")
        }
        if (modifiers & Int(NSEvent.ModifierFlags.control.rawValue)) != 0 {
            symbols.append("⌃")
        }
        
        let result = symbols.joined()
        return result
    }
    
    /// 使用UCKeyTranslate尝试从虚拟键码获取字符
    /// Attempts to get character from virtual key code using UCKeyTranslate
    private func getStringFromVirtualKeyCode(_ keyCode: Int) -> String {
        
        // 获取当前键盘布局
        // Get current keyboard layout
        guard let currentKeyboard = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return ""
        }
        
        
        // 安全获取布局数据属性
        // Safely get layout data property
        let layoutDataPtr = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        if layoutDataPtr == nil {
            return ""
        }
        
        
        // 转换为CFData - takeUnretainedValue() 返回的是非可选类型，所以不需要 guard let
        // Convert to CFData - takeUnretainedValue() returns a non-optional type, so no guard let needed
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr!).takeUnretainedValue()
        
        // 获取键盘布局指针
        // Get keyboard layout pointer
        guard let layoutPtr = CFDataGetBytePtr(layoutData) else {
            return ""
        }
        
        
        let keyboardLayout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(layoutPtr))
        
        // 转换键码到字符
        // Convert key code to character
        var deadKeyState: UInt32 = 0
        var stringBuffer = [UniChar](repeating: 0, count: 4)
        var actualStringLength: Int = 0
        
        // 调用UCKeyTranslate
        // Call UCKeyTranslate
        let result = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,  // No modifier
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &actualStringLength,
            &stringBuffer
        )
        
        if result == noErr && actualStringLength > 0 {
            let resultString = String(utf16CodeUnits: stringBuffer, count: actualStringLength)

            return resultString
        } else {

        }
        
        return ""
    }
} 
