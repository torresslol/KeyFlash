import Cocoa
import Combine
import os.log

class AccessibilityService {
    // MARK: - Properties
    
    /// Logger
    private let logger = Logger(subsystem: "com.easytime.keyflash", category: "AccessibilityService")
    
    /// Shared instance (singleton)
    static let shared = AccessibilityService()
    
    /// Whether the panel is currently displayed
    private var isPanelShowing = false
    
    /// Current active application
    private var currentFocusedApplication: NSRunningApplication?
    
    // Enable detailed logging
    private let debugMode = true
    
    // Permission status publisher
    private let permissionStatusSubject = CurrentValueSubject<Bool, Never>(false)
    var permissionStatusPublisher: AnyPublisher<Bool, Never> {
        permissionStatusSubject.eraseToAnyPublisher()
    }
    
    // Last permission check result, used to reduce duplicate logs
    private var lastPermissionStatus: Bool = false
    
    // Flag to track if initial check has been completed
    private var hasCompletedInitialCheck = false
    
    // Whether to check permission on application activation
    private var shouldCheckOnActivate = false
    
    // MARK: - Initialization
    
    private init() {
        logDebug("AccessibilityService initialization")
        
        // Register notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleApplicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Initialize current active application
        currentFocusedApplication = NSWorkspace.shared.frontmostApplication
        
        // Check permission status once on initialization
        let hasPermission = checkPermissionStatus()
        
        // If no permission, proactively request authorization
        if !hasPermission {
            logDebug("No accessibility permission, will show permission request after app launch")
            // Delay execution to ensure the app has fully launched
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showPermissionRequestDialog { userAccepted in
                    if userAccepted {
                        self?.logDebug("User agreed to request permission, opening system settings")
                    } else {
                        self?.logDebug("User temporarily rejected the permission request")
                        // Show limited functionality tip
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let alert = NSAlert()
                            alert.messageText = "Limited Functionality"
                            alert.informativeText = "Without accessibility permission, KeyFlash won't be able to detect shortcuts from other applications."
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
            }
        }
        
        // Mark initial check as completed
        hasCompletedInitialCheck = true
        
        // Disable automatic checking by default
        shouldCheckOnActivate = false
        
        // Listen for application activation state, check permission status when the application is activated (only when configured)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        logDebug("AccessibilityService initialization completed")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Enable or disable automatic permission checking on application activation
    /// - Parameter enabled: Whether to enable automatic checking
    func setAutoCheckOnActivate(enabled: Bool) {
        shouldCheckOnActivate = enabled
        logDebug("Automatic permission checking on application activation has been \(enabled ? "enabled" : "disabled")")
    }
    
    /// Check if accessibility permission has been granted
    /// - Returns: Whether permission is granted
    func isAccessibilityPermissionGranted() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        // Only log when status changes or when forced
        if hasPermission != lastPermissionStatus {
            logDebug("Check accessibility permission: \(hasPermission ? "Authorized" : "Unauthorized")", force: true)
            lastPermissionStatus = hasPermission
            
            // Only send notification when permission status changes
            permissionStatusSubject.send(hasPermission)
        }
        
        return hasPermission
    }
    
    /// Request accessibility permission
    /// - Parameter showSystemPreferences: Whether to show system preferences
    /// - Returns: Permission status after request
    @discardableResult
    func requestAccessibilityPermission(showSystemPreferences: Bool = true) -> Bool {
        logDebug("Request accessibility permission, show system preferences: \(showSystemPreferences)")
        
        // If already have permission, return true directly
        if isAccessibilityPermissionGranted() {
            logDebug("Already have accessibility permission, no need to request")
            return true
        }
        
        if showSystemPreferences {
            // Open system preferences accessibility panel
            logDebug("Opening system preferences accessibility panel")
            openSystemPreferencesAccessibility()
        } else {
            // Requesting permission will display a system dialog
            logDebug("Showing system permission request dialog")
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(options)
        }
        
        let result = isAccessibilityPermissionGranted()
        logDebug("Permission status after requesting accessibility permission: \(result ? "Authorized" : "Unauthorized")")
        return result
    }
    
    /// Get the current active application
    /// - Returns: Current active application, or nil if unable to get
    func getCurrentFocusedApplication() -> NSRunningApplication? {
        let frontApp = NSWorkspace.shared.frontmostApplication
        if let app = frontApp {
            logDebug("Current active application: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
        } else {
            logDebug("Unable to get current active application")
        }
        return frontApp
    }
    
    /// Open system preferences accessibility panel
    func openSystemPreferencesAccessibility() {
        var url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        
        // macOS Ventura and above use a new URL scheme
        if #available(macOS 13.0, *) {
            url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")
        }
        
        if let url = url {
            logDebug("Opening system preferences: \(url.absoluteString)")
            NSWorkspace.shared.open(url)
        } else {
            // If unable to open specific panel, open main security and privacy panel
            logDebug("Unable to open specific panel, opening main security and privacy panel")
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
        }
    }
    
    /// Show permission request explanation window
    func showPermissionRequestDialog(completion: @escaping (Bool) -> Void) {
        logDebug("Showing permission request explanation window")
        
        let alert = NSAlert()
        alert.messageText = "accessibility_alert_title".localized
        alert.informativeText = "accessibility_alert_message".localized
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "accessibility_alert_button_open_prefs".localized)
        alert.addButton(withTitle: "accessibility_alert_button_later".localized)
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // User chose to open system preferences
            logDebug("User chose to open system preferences")
            openSystemPreferencesAccessibility()
            completion(true)
        } else {
            // User chose to do it later
            logDebug("User chose to do it later")
            completion(false)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkPermissionStatus() -> Bool {
        // Check if this is the initial check
        let isInitialCheck = !hasCompletedInitialCheck
        
        let hasPermission = isAccessibilityPermissionGranted()
        
        // If this is the initial check, add a prompt
        if isInitialCheck {
            logDebug("Initial permission status check: \(hasPermission ? "Authorized" : "Unauthorized")")
        }
        
        // Only log when status changes
        if permissionStatusSubject.value != hasPermission {
            logDebug("Permission status changed: \(hasPermission ? "Authorized" : "Unauthorized")")
            permissionStatusSubject.send(hasPermission)
        }
        
        return hasPermission
    }
    
    @objc private func applicationDidBecomeActive() {
        // If automatic checking is disabled, return directly
        if !shouldCheckOnActivate {
            return
        }
        
        // If panel is being displayed, skip permission check
        if isPanelShowing {
            logDebug("Panel is being displayed, skipping permission check")
            return
        }
        
        // Check permission status when application is activated
        logDebug("Application activated, checking permission status")
        checkPermissionStatus()
    }
    
    @objc private func handleApplicationActivated(_ notification: Notification) {
        // Update current focused app
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            currentFocusedApplication = app
            logDebug("Application activated: \(app.localizedName ?? "unknown")")
        }
    }
    
    // MARK: - Logging
    
    func logDebug(_ message: String, force: Bool = false) {
        if debugMode || force {
            // Only use one logging method to avoid duplication
            print("[AccessibilityService] \(message)")
        }
    }
    
    // Add method to set panel display status
    func setPanelShowing(_ showing: Bool) {
        isPanelShowing = showing
        logDebug("Panel display status set to: \(showing)")
    }
} 
