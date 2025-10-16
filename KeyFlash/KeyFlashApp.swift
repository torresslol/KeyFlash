//
//  KeyFlashApp.swift
//  KeyFlash
//
//  Created by Torres Wang on 2025/3/19.
//

import SwiftUI
import SwiftData
import os.log
import Combine
import ServiceManagement

// Use @NSApplicationDelegateAdaptor instead of @StateObject
@main
struct KeyFlashApp: App {
    // Use @NSApplicationDelegateAdaptor instead of @StateObject
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var sharedModelContainer: ModelContainer = {
        // Create an empty model container since we don't need to store data models
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // 完全去除WindowGroup，改用Settings场景（不会自动显示窗口）
        Settings {
        }
        .commandsRemoved()
    }
}

// Application delegate, manages application lifecycle and menu bar
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    // MARK: - Properties
    
    // Logger instance
    private let logger = Logger(subsystem: "com.easytime.keyflash", category: "AppDelegate")
    
    // Enable detailed logging
    private let debugMode = true
    
    // Status bar item
    internal var statusItem: NSStatusItem?
    
    // Repository
    private var shortcutRepository: ShortcutRepository!
    
    // Capture use case
    private var captureUseCase: CaptureShortcutsUseCase!
    
    // Accessibility service
    private let accessibilityService = AccessibilityService.shared
    
    // Theme manager
    private let themeManager = ThemeManager.shared
    
    // Localization manager
    private let localizationManager = LocalizationManager.shared
    
    // Command key double-click detection
    private var lastCommandKeyDown: Date?
    private var commandKeyDownTime: Date?
    private var lastCommandKeyUpTime: Date?
    private var globalKeyMonitor: Any?
    private let commandDoublePressInterval: TimeInterval = 0.3 // Double-click command key threshold (seconds)
    private var isCommandDoubleClickEnabled = true
    private var lastPanelShowTime: Date? // Last time panel was shown
    private let panelShowCooldown: TimeInterval = 1.0 // Panel show cooldown time (seconds)
    
    // Add capture state flag as class property
    private var isCapturing = false
    
    // About window
    private var aboutWindow: NSWindow?
    
    // Shortcuts panel controller - only use this to show panel
    private(set) var shortcutsPanelController: SlidingPanelController!
    
    // Whether initialization is complete
    private var isInitialized = false
    
    // MARK: - Cancellables
    
    private var cancellables = Set<AnyCancellable>()
    
    // Application launch completion callback
    func applicationDidFinishLaunching(_ notification: Notification) {
        logDebug("Application launch completed [DEBUG]")
        
        // 对不同芯片架构进行日志记录
        #if arch(x86_64)
        logDebug("Running on Intel (x86_64) architecture")
        #elseif arch(arm64)
        logDebug("Running on Apple Silicon (arm64) architecture")
        #else
        logDebug("Running on unknown architecture")
        #endif
        
        // 禁用触控栏菜单，防止生成额外窗口
        NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = false
        
        // 立即设置为辅助应用，不延迟
        NSApplication.shared.setActivationPolicy(.accessory)
        self.logDebug("Immediately set to .accessory activation policy")
        
        // Avoid repeated initialization
        guard !isInitialized else {
            logDebug("Already initialized, skipping")
            return
        }
        
        logDebug("Starting initialization process, isInitialized=false")
        isInitialized = true
        
        // Ensure AppSettingsManager is initialized (it will automatically initialize theme and localization manager)
        logDebug("Initializing AppSettingsManager")
        _ = AppSettingsManager.shared
        
        // Initialize repository
        logDebug("Initializing ShortcutRepository")
        shortcutRepository = ShortcutRepositoryImpl()
        
        // Initialize capture use case
        logDebug("Initializing CaptureShortcutsUseCase")
        captureUseCase = CaptureShortcutsUseCase(
            accessibilityService: accessibilityService,
            shortcutRepository: shortcutRepository
        )
        
        // Initialize panel controller
        logDebug("Initializing SlidingPanelController")
        shortcutsPanelController = SlidingPanelController(
            appDelegate: self,
            accessibilityService: accessibilityService
        )
        
        // Set observers
        logDebug("Setting notification observers")
        setupObservers()
        
        // Initialize status bar - this is the key point
        logDebug("Preparing to initialize status bar >>> calling setupStatusBar()")
        setupStatusBar()
        logDebug("Status bar initialization completed <<< returned from setupStatusBar()")
        
        // Initialize global keyboard listener
        logDebug("Initializing global keyboard listener")
        setupGlobalKeyMonitor()
        
        // Set capture completion listener
        logDebug("Setting capture completion listener")
        setupCaptureCompletedListener()
        
        // 移除延迟执行的setActivationPolicy，因为已经立即执行了
        logDebug("Preparing to hide Dock icon")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // NSApp.setActivationPolicy(.accessory) -- 已在启动时立即执行
            // self.logDebug("Set to .accessory activation policy")
            
            // Ensure app is not focused
            if let frontmostApp = NSWorkspace.shared.frontmostApplication {
                frontmostApp.activate(options: [.activateIgnoringOtherApps])
                self.logDebug("Activated original front app: \(frontmostApp.localizedName ?? "Unknown")")
            } else {
                self.logDebug("Unable to get front app")
            }
        }
        
        // Initialization completed
        logDebug("Initialization completed")
    }
    
    // Clean up resources when application is exiting
    func applicationWillTerminate(_ notification: Notification) {
        logDebug("Application is about to terminate")
        
        // Remove global keyboard listener
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
    }
    
    // MARK: - Command double-click listener
    
    // Set global command key listener
    private func setupGlobalKeyMonitor() {
        logDebug("Setting global command key listener")
        
        guard let panelController = shortcutsPanelController else {
            logDebug("Panel controller not initialized, skipping setting global keyboard listener")
            return
        }
        
        // First reset panel state to ensure consistency
        panelController.resetPanelState()
        
        // Ensure no panel is displayed
        if panelController.isVisible {
            logDebug("Panel state inconsistent, forcing reset")
            panelController.isVisible = false
        }
        
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            logDebug("【Event tracking】0. flagsChanged event triggered")
            
            let triggerKeyManager = TriggerKeyManager.shared
            let currentTriggerKey = triggerKeyManager.currentTriggerKey
            
            // Check if only the trigger key is pressed without other modifiers
            let triggerKeyPressed = triggerKeyManager.matchesTriggerKey(event)
            let hasOtherModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask) != currentTriggerKey.modifierFlags
            
            logDebug("【Event tracking】0.1 Trigger key state: pressed=\(triggerKeyPressed), hasOtherModifiers=\(hasOtherModifiers)")
            
            if triggerKeyPressed && !hasOtherModifiers {
                let now = Date()
                
                // Check if it's a double-click trigger key
                if let lastPress = self.lastCommandKeyDown,
                   let lastRelease = self.lastCommandKeyUpTime,
                   lastRelease > lastPress, // Ensure previous was complete press and release
                   now.timeIntervalSince(lastPress) < commandDoublePressInterval,
                   now.timeIntervalSince(lastRelease) < commandDoublePressInterval { // Ensure two clicks were close enough
                    
                    logDebug("【Event tracking】1. Double-click detected")
                    
                    // Check if in cooling period
                    if let lastShow = lastPanelShowTime,
                       Date().timeIntervalSince(lastShow) < panelShowCooldown {
                        logDebug("【Event tracking】1.1 In cooling period, ignoring event")
                        return
                    }
                    
                    // Check if panel is already displayed
                    if shortcutsPanelController.panelState != .hidden {
                        logDebug("【Event tracking】1.2 Panel already displayed, ignoring this double-click")
                        return
                    }
                    
                    // Check current application
                    if let app = NSWorkspace.shared.frontmostApplication,
                       app != NSRunningApplication.current {
                        logDebug("【Event tracking】2. Calling handleCommandDoubleClick")
                        handleCommandDoubleClick(notification: Notification(name: .commandDoubleClickDetected))
                        lastPanelShowTime = now // Record panel display time
                    }
                    
                    // Reset state
                    self.lastCommandKeyDown = nil
                    self.lastCommandKeyUpTime = nil
                } else {
                    // Record first press time
                    logDebug("【Event tracking】1.3 Record first trigger key press time")
                    self.lastCommandKeyDown = now
                }
            } else if !triggerKeyPressed {
                // Record release time when trigger key is released
                logDebug("【Event tracking】1.4 Record trigger key release time")
                self.lastCommandKeyUpTime = Date()
            }
        }
    }
    
    // Set capture completion listener
    private func setupCaptureCompletedListener() {
        captureUseCase.captureCompletedPublisher
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("【Event tracking】X. Capture shortcuts failed: \(error.localizedDescription)")
                    }
                    // Ensure reset capture flag when done, regardless of success or failure
                    self?.isCapturing = false
                    self?.logDebug("【Event tracking】3.X.3 Reset capture flag isCapturing=false because Publisher completed")
                },
                receiveValue: { [weak self] application in
                    self?.logDebug("【Event tracking】4. captureCompletedPublisher received capture completion event")
                    
                    // Check panel state to avoid repeated display
                    if let self = self, self.shortcutsPanelController.panelState == .hidden && !self.shortcutsPanelController.hasWindow {
                        self.showShortcutsPanel(for: application)
                    } else {
                        self?.logDebug("【Event tracking】4.1 Panel already displayed, ignoring this capture completion event")
                    }
                    
                    // Ensure reset capture flag
                    self?.isCapturing = false
                    self?.logDebug("【Event tracking】4.2 Reset capture flag isCapturing=false")
                }
            )
            .store(in: &cancellables)
    }
    
    // Show shortcuts panel
    private func showShortcutsPanel(for application: ShortcutApplicationEntity) {
        logDebug("【Event tracking】5. showShortcutsPanel called, application: \(application.name)")
        
        // Only use SlidingPanelController to show panel
        logDebug("【Event tracking】5.2 Calling shortcutsPanelController.showPanelForApplication")
        shortcutsPanelController.showPanelForApplication(application)
    }
    
    // Handle Command double-click event
    private func handleCommandDoubleClick(notification: Notification) {
        let callStack = Thread.callStackSymbols
        logDebug("【Event tracking】3. handleCommandDoubleClick starting, call stack: \(callStack[1...min(3, callStack.count-1)].joined(separator: "\n"))")
        
        // Check current panel state
        logDebug("【Event tracking】3.0 Check current panel state: panelState=\(shortcutsPanelController.panelState), hasWindow=\(shortcutsPanelController.hasWindow)")
        
        // Check state consistency
        if shortcutsPanelController.hasWindow && shortcutsPanelController.panelState == .hidden ||
           !shortcutsPanelController.hasWindow && shortcutsPanelController.panelState != .hidden {
            logDebug("【Event tracking】3.0.0 Panel state inconsistent, reset panel state")
            shortcutsPanelController.resetPanelState()
        }
        
        // If panel is already displayed, don't trigger capture again
        if shortcutsPanelController.panelState != .hidden || shortcutsPanelController.hasWindow {
            logDebug("【Event tracking】3.0.1 Panel already displayed or window exists, skipping capture")
            return
        }
        
        // Remove invalid observersForName calls
        logDebug("【Event tracking】3.0.2 Handling .commandDoubleClickDetected notification")
        
        // Get current active application
        guard let currentApp = NSWorkspace.shared.frontmostApplication, currentApp != NSRunningApplication.current else {
            logDebug("【Event tracking】3.X Current active application is KeyFlash itself or unable to get, not processing")
            return
        }
        
        // Check if already in capture process
        if isCapturing {
            logDebug("【Event tracking】3.X.1 Already in capture, ignoring repeated request")
            return
        }
        
        // Set capture flag
        isCapturing = true
        logDebug("【Event tracking】3.X.2 Set capture flag isCapturing=true")
        
        logDebug("【Event tracking】3.1 Capturing shortcuts from application \(currentApp.localizedName ?? "Unknown")")
        
        // Use critical section to prevent simultaneous execution of multiple captures
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                self?.isCapturing = false
                return 
            }
            
            // Again check state to ensure no changes
            if self.shortcutsPanelController.panelState != .hidden || self.shortcutsPanelController.hasWindow {
                self.logDebug("【Event tracking】3.2 State changed, not executing capture")
                self.isCapturing = false
                return
            }
            
            // Manually trigger shortcut capture
            self.logDebug("【Event tracking】3.3 Starting shortcut capture")
            self.captureUseCase.captureShortcutsFromCurrentApplication()
            
            // Delay reset capture flag to allow capture to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isCapturing = false
                self.logDebug("【Event tracking】3.4 Reset capture flag isCapturing=false")
            }
        }
    }
    
    // Show regular floating window - only used for displaying simple messages, not for displaying shortcuts
    private func showFloatingWindow(with message: String) {
        logDebug("Showing message floating window: \(message)")
        
        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Set window properties
        window.title = "KeyFlash"
        window.center()
        window.isReleasedWhenClosed = true
        window.level = .floating // Set to floating window, always on top
        window.backgroundColor = NSColor.windowBackgroundColor
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Set content view
        let contentView = NSHostingView(
            rootView: VStack {
                Text(message)
                    .font(.system(size: 16))
                    .padding()
                    .multilineTextAlignment(.center)
                
                Button("OK") {
                    window.close()
                }
                .padding()
            }
            .frame(width: 400, height: 300)
        )
        contentView.frame = window.contentView!.bounds
        window.contentView!.addSubview(contentView)
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Hide panel (if needed)
    func hidePanelIfNeeded() {
        logDebug("Hiding shortcuts panel")
        
        // Safely access panel controller
        if let panelController = shortcutsPanelController {
            // Request panel hide
            panelController.requestHidePanel()
        }
    }
    
    // MARK: - Status Bar Menu
    
    private func setupStatusBar() {
        logDebug("Setting status bar - starting initialization [DEBUG]")
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        logDebug("Setting status bar - status bar item created, statusItem pointer: \(String(describing: statusItem))")
        
        // Set icon
        if let button = statusItem?.button {
            logDebug("Setting status bar - status bar button available, button pointer: \(String(describing: button))")
            
            // Check if icon loaded successfully
            if let menuImage = NSImage(named: "menu") {
                logDebug("Setting status bar - Menu icon loaded successfully, size: \(menuImage.size)")
                button.image = menuImage
                logDebug("Setting status bar - Icon set to button")
            } else {
                logDebug("Setting status bar - Warning: Menu icon 'menu' failed to load!")
            }
            
            // Important change: Do not set button's action and target
            // button.action = #selector(statusItemClicked(_:))
            // button.target = self
            logDebug("Setting status bar - Do not set button action, use standard menu handling")
        } else {
            logDebug("Setting status bar - Error: Unable to get status bar button!")
        }
        
        // Initialize menu
        let menu = createStatusBarMenuItems()
        logDebug("Setting status bar - Initial menu created, item count: \(menu.items.count)")
        statusItem?.menu = menu
        logDebug("Setting status bar - Initial menu set to status bar, current status bar menu item count: \(statusItem?.menu?.items.count ?? 0)")
        
        // Check menu item settings
        if let menuItems = statusItem?.menu?.items {
            logDebug("Setting status bar - Menu item check:")
            for (index, item) in menuItems.enumerated() {
                logDebug("   Menu item[\(index)]: Title=\"\(item.title)\", Has action=\(item.action != nil), Has target=\(item.target != nil)")
            }
        }
    }
    
    /// Create menu items
    private func createStatusBarMenuItems() -> NSMenu {
        logDebug("Creating menu items - starting [DEBUG]")
        
        let menu = NSMenu()
        menu.delegate = self // Set as menu delegate to capture menu events
        logDebug("Creating menu items - Creating empty menu, setting delegate")
        
        // 1. Show Panel
        menu.addItem(NSMenuItem(title: "menu_show_panel".localized, action: #selector(showPanel), keyEquivalent: ""))
        
        // 2. Clear Cache
        menu.addItem(NSMenuItem(title: "menu_clear_cache".localized, action: #selector(clearCache), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Hotkey Settings
        let hotkeyItem = NSMenuItem(title: "menu_hotkey".localized, action: nil, keyEquivalent: "")
        let hotkeySubmenu = NSMenu()
        
        for key in TriggerKey.allCases {
            let item = NSMenuItem(title: "\(key.keyCharacter) × 2", action: #selector(triggerKeySelected(_:)), keyEquivalent: "")
            item.representedObject = key
            item.target = self
            if key == TriggerKeyManager.shared.currentTriggerKey {
                item.state = .on
            }
            hotkeySubmenu.addItem(item)
        }
        
        hotkeyItem.submenu = hotkeySubmenu
        menu.addItem(hotkeyItem)
        
        // 4. Theme
        let themeItem = NSMenuItem(title: "menu_theme".localized, action: nil, keyEquivalent: "")
        let themeSubmenu = NSMenu()
        for theme in ThemeMode.allCases {
            let item = NSMenuItem(title: theme.displayName, action: #selector(themeSelected(_:)), keyEquivalent: "")
            item.representedObject = theme
            item.target = self
            if theme == themeManager.currentThemeMode {
                item.state = .on
            }
            themeSubmenu.addItem(item)
        }
        themeItem.submenu = themeSubmenu
        menu.addItem(themeItem)
        
        // 5. Language
        let languageItem = NSMenuItem(title: "menu_language".localized, action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.displayName, action: #selector(languageSelected(_:)), keyEquivalent: "")
            item.representedObject = language
            item.target = self
            if language == localizationManager.currentLanguage {
                item.state = .on
            }
            languageSubmenu.addItem(item)
        }
        languageItem.submenu = languageSubmenu
        menu.addItem(languageItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Buy Me a Coffee
        let coffeeItem = NSMenuItem(title: "buy_me_coffee".localized, action: #selector(openBuyMeACoffee), keyEquivalent: "")
        let coffeeIcon = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)
        coffeeIcon?.isTemplate = false // Keep original color
        coffeeItem.image = coffeeIcon
        menu.addItem(coffeeItem)
        
        // 7. Launch at Login (移到退出选项之前)
        let launchAtLoginItem = NSMenuItem(title: "menu_launch_at_login".localized, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        // 使用state属性，这样勾选标记会显示在左侧
        launchAtLoginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        // 8. Quit
        let quitMenuItem = NSMenuItem(title: "menu_quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quitMenuItem.target = NSApp
        menu.addItem(quitMenuItem)
        
        // Set target for all menu items
        for item in menu.items {
            if item.action != nil && item != quitMenuItem {
                item.target = self
            }
        }
        
        logDebug("Creating menu items - Completed, Created \(menu.items.count) menu items, delegate=\(String(describing: menu.delegate))")
        return menu
    }
    
    /// Create and show status bar menu
    func showStatusBarMenu(_ sender: Any? = nil) {
        logDebug("Showing status bar menu")
        
        // Create and set menu
        statusItem?.menu = createStatusBarMenuItems()
        
        // If called programmatically, simulate button click to show menu
        if sender == nil, let button = statusItem?.button {
            button.performClick(nil)
        }
    }
    
    // Handle status bar button click event - This method is no longer used, but will add detailed logging for click
    // We now use standard macOS status bar menu mechanism, let system handle click and menu display
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        logDebug("Status bar button click - Click event triggered [DEBUG]")
        logDebug("Status bar button click - sender: \(sender)")
        
        // Record current menu state
        if let menu = statusItem?.menu {
            logDebug("Status bar button click - Current menu state: Exists, item count: \(menu.items.count)")
            logDebug("Status bar button click - Menu open: \(NSMenu.menuBarVisible())")
        } else {
            logDebug("Status bar button click - Current menu is nil")
        }
        
        // Record status bar item state
        if let statusItem = self.statusItem {
            logDebug("Status bar button click - Status bar item: \(String(describing: statusItem))")
            if let button = statusItem.button {
                logDebug("Status bar button click - Button state: isEnabled=\(button.isEnabled), isHighlighted=\(button.isHighlighted)")
            }
        }
        
        // We just record, no action is taken
        logDebug("Status bar button click - This method is only for logging, no actual action is taken")
    }
    
    // MARK: - Public Methods
    
    /// Check accessibility permission status
    func checkAccessibilityPermission() -> Bool {
        return accessibilityService.isAccessibilityPermissionGranted()
    }
    
    /// Clear all cache
    func clearAllCache() {
        logDebug("Clearing all shortcut cache")
        
        shortcutRepository.clearAllCache()
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Clear cache failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] in
                    self?.logDebug("Clear cache succeeded")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Get all cached applications
    func getAllCachedApplications() -> AnyPublisher<[ShortcutApplicationEntity], Error> {
        return shortcutRepository.getAllCachedApplications()
    }
    
    // MARK: - Initialization
    
    private func setupObservers() {
        // Listen for trigger key change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerKeyDidChange(_:)),
            name: .triggerKeyDidChange,
            object: nil
        )
        
        // Listen for language change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange(_:)),
            name: .languageDidChange,
            object: nil
        )
        
        // Listen for theme change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange(_:)),
            name: .themeDidChange,
            object: nil
        )
    }
    
    @objc private func triggerKeyDidChange(_ notification: Notification) {
        logDebug("Trigger key changed, updating menu")
        updateStatusBarMenu()
    }
    
    @objc private func themeDidChange(_ notification: Notification) {
        logDebug("Theme changed, updating menu")
        updateStatusBarMenu()
    }
    
    @objc private func languageDidChange(_ notification: Notification) {
        logDebug("Language changed, updating menu")
        updateStatusBarMenu()
    }
    
    // MARK: - Status Bar Menu
    
    private func updateStatusBarMenu() {
        logDebug("Updating status bar menu - Starting")
        
        // Ensure UI update on main thread
        if Thread.isMainThread {
            logDebug("Updating status bar menu - Executing on main thread")
            statusItem?.menu = createStatusBarMenuItems()
        } else {
            logDebug("Updating status bar menu - Not on main thread, switching to main thread execution")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.logDebug("Updating status bar menu - Now executing on main thread")
                self.statusItem?.menu = self.createStatusBarMenuItems()
            }
        }
        
        logDebug("Updating status bar menu - Completed")
    }
    
    // MARK: - Menu Actions
    
    @objc private func languageSelected(_ sender: NSMenuItem) {
        if let language = sender.representedObject as? AppLanguage {
            logDebug("Selecting language: \(language.rawValue)")
            localizationManager.setLanguage(language)
            // Update menu item state
            if let languageMenu = sender.menu {
                for item in languageMenu.items {
                    item.state = (item == sender) ? .on : .off
                }
            }
        }
    }
    
    @objc private func themeSelected(_ sender: NSMenuItem) {
        if let theme = sender.representedObject as? ThemeMode {
            themeManager.changeTheme(to: theme)
            // Update menu item state
            if let themeMenu = sender.menu {
                for item in themeMenu.items {
                    item.state = (item == sender) ? .on : .off
                }
            }
        }
    }
    
    @objc private func triggerKeySelected(_ sender: NSMenuItem) {
        if let key = sender.representedObject as? TriggerKey {
            TriggerKeyManager.shared.setTriggerKey(key)
            // Update menu item state
            if let keyMenu = sender.menu {
                for item in keyMenu.items {
                    item.state = (item == sender) ? .on : .off
                }
            }
        }
    }
    
    @objc private func showPanel() {
        logDebug("Showing panel")
        if let currentApp = NSWorkspace.shared.frontmostApplication,
           currentApp != NSRunningApplication.current {
            handleCommandDoubleClick(notification: Notification(name: .commandDoubleClickDetected))
        }
    }
    
    @objc func extractCurrentAppShortcuts() {
        logDebug("Extracting current app shortcuts")
        
        // Get current active application
        guard let currentApp = NSWorkspace.shared.frontmostApplication, currentApp != NSRunningApplication.current else {
            logDebug("Current active application is KeyFlash itself or unable to get, not processing")
            showAlertMessage(title: "alert_no_app_title".localized, message: "alert_no_app_message".localized)
            return
        }
        
        logDebug("Capturing shortcuts from application \(currentApp.localizedName ?? "Unknown")")
        captureUseCase.captureShortcutsFromCurrentApplication()
    }
    
    // Show alert message
    private func showAlertMessage(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "alert_ok".localized)
        alert.runModal()
    }
    
    @objc private func showAllCachedShortcuts() {
        logDebug("View all cached shortcuts")
        // TODO: Display all cached shortcuts
    }
    
    @objc private func clearCache() {
        logDebug("User clicked Clear cache menu")
        clearAllCache()
    }
    
    @objc func exportShortcuts() {
        logDebug("Export shortcuts (To be implemented)")
        // TODO: Implement export shortcuts functionality
    }
    
    @objc func showAboutPanel() {
        logDebug("Showing about panel")
        showAbout()
    }
    
    @objc func showSettingsPanel() {
        logDebug("Showing settings panel")
        showStatusBarMenu()
    }
    
    func showAbout() {
        logDebug("Showing about window")
        
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .normal
            window.title = "About"
            
            // Create content view for about window
            let contentView = NSHostingView(
                rootView: VStack(spacing: 20) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("KeyFlash")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Version 1.0")
                        .font(.caption)
                    
                    Text("© 2024 Torres Wang")
                        .font(.caption2)
                    
                    HStack {
                        Button {
                            self.openBuyMeACoffee()
                        } label: {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                    .foregroundColor(.brown)
                                Text("Buy Me a Coffee")
                            }
                            .padding(.horizontal)
                        }
                        
                        Button("Close") {
                            window.close()
                        }
                        .keyboardShortcut(.defaultAction)
                        .padding(.horizontal)
                    }
                }
                .frame(width: 300, height: 250)
                .padding()
            )
            
            contentView.frame = window.contentView!.bounds
            window.contentView!.addSubview(contentView)
            window.delegate = self
            
            self.aboutWindow = window
            logDebug("About window created")
        }
        
        self.aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logDebug("About window displayed")
    }
    
    // MARK: - Logging
    
    private func logDebug(_ message: String) {
        if debugMode {
            logger.debug("\(message)")
            print("[AppDelegate] \(message)")
        }
    }
    
    // MARK: - NSWindowDelegate
    
    // Handle window closing event
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == aboutWindow {
            logDebug("About window is about to close")
            // No special processing when window closes, just log
            // App remains running state
        }
    }
    
    // Handle window close button click event
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == aboutWindow {
            logDebug("About window close button clicked")
            // Just hide window, don't really close it
            sender.orderOut(nil)
            return false // Return false to not really close window
        }
        return true
    }
    
    func requestAccessibilityPermission() {
        accessibilityService.requestAccessibilityPermission(showSystemPreferences: true)
    }
    
    @objc func openBuyMeACoffee() {
        logDebug("Opening Buy Me a Coffee link")
        if let url = URL(string: "https://buymeacoffee.com/torreslol") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func toggleLaunchAtLogin() {
        logDebug("Toggling launch at login")
        LaunchAtLoginManager.shared.toggle()
        
        // 更新菜单状态
        updateStatusBarMenu()
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    // Menu will open callback
    func menuWillOpen(_ menu: NSMenu) {
        logDebug("Menu will open: \(menu), item count: \(menu.items.count)")
    }
    
    // Menu close callback
    func menuDidClose(_ menu: NSMenu) {
        logDebug("Menu closed: \(menu)")
    }
    
    // Get menu item display status callback (Called for each item)
    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        // Only log for first menu item, avoid too much logging
        if index == 0 {
            logDebug("Menu item update: Menu=\(menu), Current updating item \(index): \"\(item.title)\"")
        }
        return true // Indicates update handled
    }
    
    // Menu will display menu items callback
    func menuNeedsUpdate(_ menu: NSMenu) {
        logDebug("Menu needs update: \(menu), item count: \(menu.items.count)")
    }
}

// 添加LaunchAtLoginManager类，放在AppDelegate之前
class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private let logger = Logger(subsystem: "com.easytime.keyflash", category: "LaunchAtLoginManager")
    
    var isEnabled: Bool {
        get {
            // 如果没有设置过，默认为true（开启开机自启动）
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            applyLaunchAtLoginSetting()
        }
    }
    
    init() {
        // 如果是首次启动且没有设置过，默认开启开机自启动
        if UserDefaults.standard.object(forKey: "launchAtLogin") == nil {
            UserDefaults.standard.set(true, forKey: "launchAtLogin")
        }
        
        // 读取之前的设置并应用
        applyLaunchAtLoginSetting()
    }
    
    func applyLaunchAtLoginSetting() {
        if #available(macOS 13.0, *) {
            // 使用现代API (macOS 13+)
            do {
                let enabled = isEnabled
                logger.debug("Applying launch at login setting: \(enabled)")
                
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                logger.error("Failed to set launch at login: \(error.localizedDescription)")
            }
        } else {
            // 使用旧版API (macOS 12及更早版本)
            applyLegacyLaunchAtLoginSetting()
        }
    }
    
    private func applyLegacyLaunchAtLoginSetting() {
        // 获取当前应用的URL
        let appURL = Bundle.main.bundleURL.absoluteURL
        
        let enabled = isEnabled
        logger.debug("Applying legacy launch at login setting: \(enabled)")
        
        // 通过Login Items API设置
        if let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil) {
            if enabled {
                // 添加登录项
                LSSharedFileListInsertItemURL(
                    loginItems.takeRetainedValue(),
                    kLSSharedFileListItemLast.takeRetainedValue(),
                    nil,
                    nil,
                    appURL as CFURL,
                    nil,
                    nil
                )
            } else {
                // 移除登录项
                if let loginItemsArray = LSSharedFileListCopySnapshot(loginItems.takeRetainedValue(), nil)?.takeRetainedValue() as? [LSSharedFileListItem] {
                    for loginItem in loginItemsArray {
                        var urlRef: Unmanaged<CFURL>?
                        
                        // 获取项目的URL
                        LSSharedFileListItemResolve(
                            loginItem,
                            0,
                            &urlRef,
                            nil
                        )
                        
                        if let urlRef = urlRef, let itemURL = urlRef.takeRetainedValue() as URL?, itemURL.absoluteURL == appURL {
                            // 移除匹配的项
                            LSSharedFileListItemRemove(
                                loginItems.takeRetainedValue(),
                                loginItem
                            )
                        }
                    }
                }
            }
        }
    }
    
    func toggle() {
        isEnabled = !isEnabled
    }
}

