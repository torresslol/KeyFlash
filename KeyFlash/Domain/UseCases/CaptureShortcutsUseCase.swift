import Foundation
import Combine
import AppKit
import os.log

/// 捕获快捷键用例，处理从当前应用捕获快捷键的业务逻辑
/// Use case for capturing shortcuts, handles the business logic for capturing shortcuts from the current application
class CaptureShortcutsUseCase {
    // MARK: - Properties
    
    /// 日志记录器
    /// Logger
    private let logger = Logger(subsystem: "com.easytime.keyflash", category: "CaptureShortcutsUseCase")
    
    // 是否启用详细日志
    // Whether detailed logging is enabled
    private let debugMode = true
    
    // 性能追踪
    // Performance tracking
    private var captureStartTime: CFAbsoluteTime = 0
    private var menuExtractionStartTime: CFAbsoluteTime = 0
    
    // 键盘事件监视器 - 不再需要
    // Keyboard event monitor - no longer needed
    // private let keyboardEventMonitor: KeyboardEventMonitor
    
    /// 菜单栏提取器
    /// Menu bar extractor
    private let menuBarExtractor: MenuBarExtractor
    
    // 辅助功能服务
    // Accessibility service
    private let accessibilityService: AccessibilityService
    
    // 快捷键仓库
    // Shortcut repository
    private let shortcutRepository: ShortcutRepository
    
    // 订阅集合
    // Subscription set
    private var cancellables = Set<AnyCancellable>()
    
    // 完成发布者
    // Completion publisher
    private let captureCompletedSubject = PassthroughSubject<ApplicationEntity, Error>()
    var captureCompletedPublisher: AnyPublisher<ApplicationEntity, Error> {
        captureCompletedSubject.eraseToAnyPublisher()
    }
    
    // 进度发布者
    // Progress publisher
    private let captureProgressSubject = PassthroughSubject<Float, Never>()
    var captureProgressPublisher: AnyPublisher<Float, Never> {
        captureProgressSubject.eraseToAnyPublisher()
    }
    
    // 权限状态发布者
    // Permission status publisher
    private let permissionStatusSubject = PassthroughSubject<Bool, Never>()
    var permissionStatusPublisher: AnyPublisher<Bool, Never> {
        permissionStatusSubject.eraseToAnyPublisher()
    }
    
    // 特权应用警告发布者
    // Privileged application warning publisher
    private let privilegedAppWarningSubject = PassthroughSubject<String, Never>()
    var privilegedAppWarningPublisher: AnyPublisher<String, Never> {
        privilegedAppWarningSubject.eraseToAnyPublisher()
    }
    
    // 是否正在捕获
    // Whether capture is currently in progress
    private var isCapturing = false
    
    // 启动时是否检查权限
    // Whether to check permission on startup
    private let checkPermissionOnStart: Bool
    
    // MARK: - Initialization
    
    init(
        // keyboardEventMonitor: KeyboardEventMonitor = KeyboardEventMonitor(),
        menuBarExtractor: MenuBarExtractor? = nil,
        accessibilityService: AccessibilityService,
        shortcutRepository: ShortcutRepository = ShortcutRepositoryImpl(),
        checkPermissionOnStart: Bool = true
    ) {
        // self.keyboardEventMonitor = keyboardEventMonitor
        self.menuBarExtractor = menuBarExtractor ?? MenuBarExtractor(accessibilityService: accessibilityService)
        self.accessibilityService = accessibilityService
        self.shortcutRepository = shortcutRepository
        self.checkPermissionOnStart = checkPermissionOnStart
        
        logDebug("CaptureShortcutsUseCase Initialization") // Initialization
        setupSubscriptions()
    }
    
    deinit {
        logDebug("CaptureShortcutsUseCase Destruction") // Destruction
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Public Methods
    
    /// 开始监听命令键双击事件 - 不再需要，现在由AppDelegate直接处理
    /// Start monitoring command key double-click events - no longer needed, now handled directly by AppDelegate
    func startMonitoring() {
        // No longer need to check permissions
        logDebug("Start monitoring (this method is kept but simplified)") // Start monitoring (this method is kept but simplified)
    }
    
    /// 停止监听命令键双击事件 - 不再需要，现在由AppDelegate直接处理
    /// Stop monitoring command key double-click events - no longer needed, now handled directly by AppDelegate
    func stopMonitoring() {
        // No longer need to stop keyboard monitoring
        logDebug("Stop monitoring command key double-click events") // Stop monitoring command key double-click events
    }
    
    /// 手动触发从当前应用捕获快捷键
    /// Manually trigger capturing shortcuts from the current application
    func captureShortcutsFromCurrentApplication() {
        captureStartTime = CFAbsoluteTimeGetCurrent()
        logPerformance("Start capturing shortcuts") // Start capturing shortcuts
        
        // Prevent duplicate captures
        guard !isCapturing else {
            logDebug("Already capturing, ignoring this request") // Already capturing, ignoring this request
            // Don't send an error, just ignore the request
            return
        }
        isCapturing = true
        
        // Assume permission check is handled by AppDelegate, focus only on the current active application here
        // Get current active application
        guard let currentApp = accessibilityService.getCurrentFocusedApplication() else {
            logPerformance("Failed to get current application") // Failed to get current application
            isCapturing = false
            captureCompletedSubject.send(completion: .failure(CaptureError.noActiveApplication))
            return
        }
        
        guard let bundleIdentifier = currentApp.bundleIdentifier else {
            logPerformance("Failed to get application identifier") // Failed to get application identifier
            isCapturing = false
            captureCompletedSubject.send(completion: .failure(CaptureError.noActiveApplication))
            return
        }
        
        logPerformance("Current application: \(currentApp.localizedName ?? "Unknown") (\(bundleIdentifier))") // Current application: ...
        extractShortcutsFromApplication()
    }
    
    /// 取消当前的捕获操作
    /// Cancel the current capture operation
    func cancelCapture() {
        logDebug("Cancel current capture operation") // Cancel current capture operation
        menuBarExtractor.cancelExtraction()
        isCapturing = false
    }
    
    // MARK: - Private Methods
    
    /// 从应用程序直接提取快捷键
    /// Extract shortcuts directly from the application
    private func extractShortcutsFromApplication() {
        menuExtractionStartTime = CFAbsoluteTimeGetCurrent()
        logPerformance("Start extracting menus") // Start extracting menus
        menuBarExtractor.extractShortcutsFromCurrentApplication()
    }
    
    /// 从缓存加载快捷键
    /// Load shortcuts from cache
    private func loadShortcutsFromCache(bundleIdentifier: String) {
        shortcutRepository.getApplicationShortcuts(bundleIdentifier: bundleIdentifier)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Failed to load shortcuts from cache: \(error.localizedDescription)") // Failed to load shortcuts from cache
                        // If cache loading fails, directly extract new shortcuts
                        self?.extractShortcutsFromApplication()
                    }
                    self?.isCapturing = false
                },
                receiveValue: { [weak self] application in
                    guard let self = self else { return }
                    
                    if let application = application {
                        logDebug("Successfully loaded shortcuts from cache: \(application.name), Menu item count: \(application.menuItems.count)") // Successfully loaded shortcuts from cache: ..., Menu item count: ...
                        // Print all shortcuts (for debugging only)
                        printShortcuts(application)
                        // Notify observers that capture is complete
                        captureCompletedSubject.send(application)
                    } else {
                        logDebug("No data in cache, extracting shortcuts from application") // No data in cache, extracting shortcuts from application
                        extractShortcutsFromApplication()
                    }
                    
                    self.isCapturing = false
                }
            )
            .store(in: &cancellables)
    }
    
    /// 打印快捷键（调试用）
    /// Print shortcuts (for debugging)
    private func printShortcuts(_ application: ApplicationEntity) {
        logDebug("Application: \(application.name) (\(application.bundleIdentifier))") // Application:
        logDebug("Menu item count: \(application.menuItems.count)") // Menu item count:
        
        // Group by menu group
        let groupedMenuItems = Dictionary(grouping: application.menuItems) { $0.menuGroup }
        
        for (group, items) in groupedMenuItems.sorted(by: { $0.key < $1.key }) {
            logDebug("===== \(group) =====")
            
            // Filter menu items with shortcuts
            let shortcutItems = items.filter { $0.shortcutDescription != nil }
            
            for item in shortcutItems.sorted(by: { $0.menuPath < $1.menuPath }) {
                if let shortcut = item.shortcutDescription {
                    logDebug("\(item.menuPath): \(shortcut)")
                }
            }
        }
    }
    
    private func setupSubscriptions() {
        // No longer need to listen for command key double-click events
        // keyboardEventMonitor.commandDoubleClickPublisher
        //    .receive(on: RunLoop.main)
        //    .sink { [weak self] _ in
        //        self?.logDebug("Detected command key double-click") // Detected command key double-click
        //        self?.captureShortcutsFromCurrentApplication()
        //    }
        //    .store(in: &cancellables)
        
        // Listen for menu extraction progress (only log multiples of 25%)
        menuBarExtractor.extractionProgressPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                if progress == 1.0 || (progress * 100).truncatingRemainder(dividingBy: 25) == 0 {
                    self?.logPerformance("Menu extraction progress: \(Int(progress * 100))%") // Menu extraction progress:
                }
                self?.captureProgressSubject.send(progress)
            }
            .store(in: &cancellables)
        
        // Listen for menu extraction completion event
        menuBarExtractor.extractionCompletedPublisher
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    if case let .failure(error) = completion {
                        logPerformance("Menu extraction failed: \(error.localizedDescription)") // Menu extraction failed:
                        captureCompletedSubject.send(completion: .failure(error))
                    }
                    
                    isCapturing = false
                },
                receiveValue: { [weak self] appWithShortcuts in
                    guard let self = self else { return }
                    
                    let extractionTime = CFAbsoluteTimeGetCurrent() - menuExtractionStartTime
                    logPerformance("Menu extraction complete (\(String(format: "%.2f", extractionTime))s), got \(appWithShortcuts.menuItems.count) menu items") // Menu extraction complete (...s), got ... menu items
                    
                    // Save to repository
                    shortcutRepository.saveApplicationShortcuts(appWithShortcuts)
                        .receive(on: RunLoop.main)
                        .sink(
                            receiveCompletion: { [weak self] completion in
                                guard let self = self else { return }
                                
                                if case let .failure(error) = completion {
                                    logPerformance("Failed to save shortcuts: \(error.localizedDescription)") // Failed to save shortcuts:
                                    captureCompletedSubject.send(completion: .failure(error))
                                }
                                
                                isCapturing = false
                            },
                            receiveValue: { [weak self] _ in
                                guard let self = self else { return }
                                
                                let totalTime = CFAbsoluteTimeGetCurrent() - captureStartTime
                                logPerformance("Capture complete, total time: \(String(format: "%.2f", totalTime))s") // Capture complete, total time:
                                captureCompletedSubject.send(appWithShortcuts)
                                
                                isCapturing = false
                            }
                        )
                        .store(in: &cancellables)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Logging
    
    private func logPerformance(_ message: String) {
        let timestamp = CFAbsoluteTimeGetCurrent() - captureStartTime
        print("[Performance] [\(String(format: "%.3f", timestamp))s] \(message)") // [Performance]
    }
    
    private func logDebug(_ message: String) {
        if debugMode {
            print("[Debug] \(message)") // [Debug]
        }
    }
}

// MARK: - Errors

enum CaptureError: Error {
    case accessibilityPermissionRequired
    case noActiveApplication
    case captureInProgress
    case saveFailed
    
    var localizedDescription: String {
        switch self {
        case .accessibilityPermissionRequired:
            return "Need Accessibility permission to capture shortcuts. Please authorize in System Preferences."
        case .noActiveApplication:
            return "Unable to get the current active application."
        case .captureInProgress:
            return "Capturing shortcuts in progress, please wait for the current operation to complete."
        case .saveFailed:
            return "Failed to save shortcuts. Please check system logs for more information."
        }
    }
} 
