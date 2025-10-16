import SwiftUI
import AppKit

// MARK: - Panel State Management

/// Represents the possible states of the sliding panel
enum PanelState: Equatable {
    case hidden              // Panel is completely hidden
    case appearing           // Panel is in the process of appearing
    case visible             // Panel is fully visible
    case disappearing        // Panel is in the process of disappearing
    
    var isVisible: Bool {
        return self == .visible || self == .appearing
    }
    
    var isTransitioning: Bool {
        return self == .appearing || self == .disappearing
    }
}

/// A window that accepts clicks outside its content area
class ClickOutsideWindow: NSWindow {
    var onClickOutside: (() -> Void)?
    
    // 添加判断点击是否应该被忽略的闭包属性
    // Add a closure property to determine if a click should be ignored
    var shouldIgnoreClick: ((NSPoint) -> Bool)?
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // 监听全局鼠标事件，检测窗口外的点击
    // Monitor global mouse events to detect clicks outside the window
    private var globalClickMonitor: Any?
    // 添加本地鼠标事件监听器
    // Add a local mouse event listener
    private var localClickMonitor: Any?
    
    // 接受第一响应者，以便能够监听键盘事件
    // Accept first responder to listen for keyboard events
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print("ClickOutsideWindow: awakeFromNib")
        setupClickMonitor()
    }
    
    deinit {
        print("ClickOutsideWindow: deinit")
        removeClickMonitor()
    }
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        print("ClickOutsideWindow: makeKeyAndOrderFront")
        super.makeKeyAndOrderFront(sender)
        setupClickMonitor()
    }
    
    override func orderOut(_ sender: Any?) {
        print("ClickOutsideWindow: orderOut")
        removeClickMonitor()
        super.orderOut(sender)
    }
    
    private func setupClickMonitor() {
        removeClickMonitor() // 防止重复添加 // Prevent adding duplicates
        
        print("ClickOutsideWindow: setupClickMonitor - isVisible: \(isVisible), alphaValue: \(alphaValue)")
        
        // 添加全局点击监听器
        // Add global click listener
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            print("ClickOutsideWindow: Global click detected")
            guard let self = self else {
                print("ClickOutsideWindow: Self is nil")
                return 
            }
            
            print("ClickOutsideWindow: Global click - isVisible: \(self.isVisible), alphaValue: \(self.alphaValue)")
            
            guard self.isVisible, self.alphaValue > 0 else {
                print("ClickOutsideWindow: Window visibility check failed")
                return
            }
            
            // 获取点击位置（屏幕坐标系）
            // Get click position (screen coordinates)
            let clickPointInScreen = NSEvent.mouseLocation
            print("ClickOutsideWindow: Global click position (screen): \(clickPointInScreen)")
            
            // 检查是否应该忽略这个点击（例如点击在状态栏上）
            // Check if this click should be ignored (e.g., click on the status bar)
            if let shouldIgnore = self.shouldIgnoreClick, shouldIgnore(clickPointInScreen) {
                print("ClickOutsideWindow: Global click should be ignored")
                return
            }
            
            // 将屏幕坐标系中的点转换为窗口内的点
            // Convert point from screen coordinates to window coordinates
            let clickInWindowCoords = self.convertPoint(fromScreen: clickPointInScreen)
            print("ClickOutsideWindow: Converted click position (window): \(clickInWindowCoords)")
            
            if let contentView = self.contentView {
                print("ClickOutsideWindow: Content view bounds: \(contentView.bounds)")
                // 使用窗口内坐标检查点击是否在内容视图区域内
                // Use window coordinates to check if the click is within the content view area
                if !NSPointInRect(clickInWindowCoords, contentView.bounds) {
                    print("ClickOutsideWindow: Global click is OUTSIDE - triggering callback")
                    // 使用主线程调用回调
                    // Call the callback on the main thread
                    DispatchQueue.main.async {
                        self.onClickOutside?()
                    }
                } else {
                    print("ClickOutsideWindow: Global click is INSIDE - ignoring")
                }
            } else {
                print("ClickOutsideWindow: No content view found")
            }
        }
        
        // 添加本地点击监听器作为备份
        // Add local click listener as a backup
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            print("ClickOutsideWindow: Local click detected")
            guard let self = self else {
                print("ClickOutsideWindow: Self is nil in local monitor")
                return event
            }
            
            print("ClickOutsideWindow: Local click - isVisible: \(self.isVisible), alphaValue: \(self.alphaValue)")
            guard self.isVisible, self.alphaValue > 0 else {
                print("ClickOutsideWindow: Window visibility check failed in local monitor")
                return event
            }
            
            // 检查是否应该忽略这个点击（例如点击在状态栏上）
            // Check if this click should be ignored (e.g., click on the status bar)
            if let clickLocation = event.window?.convertPoint(toScreen: event.locationInWindow),
               let shouldIgnore = self.shouldIgnoreClick, shouldIgnore(clickLocation) {
                print("ClickOutsideWindow: Local click should be ignored")
                return event
            }
            
            // 检查事件窗口是否是本窗口
            // Check if the event window is this window
            if event.window != self {
                print("ClickOutsideWindow: Local click in different window - triggering callback")
                // 如果在其他窗口中点击，触发外部点击回调
                // If clicked in another window, trigger the outside click callback
                DispatchQueue.main.async {
                    self.onClickOutside?()
                }
            
                print("ClickOutsideWindow: Local click in this window")
                // 如果在当前窗口中点击，检查是否在内容区域外
                // If clicked in the current window, check if outside the content area
                let clickInWindow = event.locationInWindow
                print("ClickOutsideWindow: Local click position (window): \(clickInWindow)")
                
                if let contentView = self.contentView {
                    print("ClickOutsideWindow: Local content view bounds: \(contentView.bounds)")
                    if !NSPointInRect(clickInWindow, contentView.bounds) {
                        print("ClickOutsideWindow: Local click is OUTSIDE content - triggering callback")
                        DispatchQueue.main.async {
                            self.onClickOutside?()
                        }
                    } else {
                        print("ClickOutsideWindow: Local click is INSIDE content - ignoring")
                    }
                } else {
                    print("ClickOutsideWindow: No content view found in local monitor")
                }
            }
            return event
        }
        
        print("ClickOutsideWindow: Monitors set up successfully")
    }
    
    private func removeClickMonitor() {
        print("ClickOutsideWindow: removeClickMonitor called")
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
            print("ClickOutsideWindow: Global monitor removed")
        }
        
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
            print("ClickOutsideWindow: Local monitor removed")
        }
    }
}

/// Sliding panel container that handles animation effects from the right side with simple sliding and fade effects
struct SlidingPanelContainer<Content: View>: View {
    // MARK: - Properties
    
    // Panel state
    @Binding var state: PanelState
    
    // Animation completion callback
    var onAnimationComplete: ((Bool) -> Void)?
    
    // Content builder
    let content: () -> Content
    
    // Screen size (for offset calculation)
    @State private var screenSize: CGSize = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
    
    // Panel dimensions
    private let panelWidth: CGFloat = 430
    private let panelHeight: CGFloat = 700
    
    // Animation state
    @State private var animationProgress: Double = 0
    
    // MARK: - Initialization
    
    init(state: Binding<PanelState>, onAnimationComplete: ((Bool) -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self._state = state
        self.onAnimationComplete = onAnimationComplete
        self.content = content
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .center) {
            // 内容面板，使用毛玻璃效果和优化的圆角
            // Content panel with visual effect and optimized rounded corners
            content()
                .frame(width: panelWidth, height: panelHeight)
                .background(
                    ZStack {
                        // 毛玻璃效果
                        // Visual effect (blur)
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .cornerRadius(16)
                        
                        // 边框效果
                        // Border effect
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(hex: "7C84A6").opacity(0.2), lineWidth: 0.5)
                            .mask(
                                RoundedRectangle(cornerRadius: 16)
                                    .padding(.trailing, -16)
                            )
                    }
                )
                // 先添加阴影
                // Add shadow first
                .shadow(color: Color.black.opacity(0.15), radius: 16, x: -8, y: 0)
                // 然后裁剪整体，包括阴影
                // Then clip the whole thing, including the shadow
                .clipShape(RoundedRectangle(cornerRadius: 16))
                // 定位到屏幕右侧中间并添加偏移动画
                // Position to the middle right of the screen and add offset animation
                .offset(x: (1 - animationProgress) * panelWidth)
                .opacity(animationProgress)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: animationProgress)
        }
        .frame(width: panelWidth, height: panelHeight)
        .onChange(of: state) { newValue in
            switch newValue {
            case .appearing:
                showPanelWithAnimation()
            case .disappearing:
                hidePanel()
            case .visible:
                // Ensure panel is fully visible
                if animationProgress < 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        animationProgress = 1
                    }
                }
            case .hidden:
                // Ensure panel is fully hidden
                if animationProgress > 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        animationProgress = 0
                    }
                }
            }
        }
        .onAppear {
            // 更新屏幕尺寸
            // Update screen size
            if let screen = NSScreen.main {
                screenSize = screen.frame.size
            }
            
            // 如果一开始是appearing或visible状态，设置动画进度为1
            // If initially in appearing or visible state, set animation progress to 1
            if state == .appearing || state == .visible {
                // 使用延迟以确保状态正确设置
                // Use delay to ensure state is set correctly
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        self.animationProgress = 1
                    } completion: {
                        // 如果状态是appearing，完成后设置为visible
                        // If state was appearing, set to visible on completion
                        if self.state == .appearing {
                            self.onAnimationComplete?(true)
                        }
                    }
                }
            }
            
            // 添加通知监听
            // Add notification observer
            NotificationCenter.default.addObserver(forName: NSNotification.Name("HidePanelRequest"), 
                                                  object: nil, 
                                                  queue: .main) { [self] _ in
                self.hidePanel()
            }
        }
        .onDisappear {
            // 移除通知监听
            // Remove notification observer
            NotificationCenter.default.removeObserver(self, 
                                                     name: NSNotification.Name("HidePanelRequest"), 
                                                     object: nil)
        }
    }
    
    // 显示面板，带有动画
    // Show panel with animation
    private func showPanelWithAnimation() {
        // 不使用动画直接设置初始状态
        // Set initial state directly without animation
        animationProgress = 0
        
        // 使用更流畅的动画
        // Use a smoother animation
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                self.animationProgress = 1
            } completion: {
                // 动画完成时调用回调
                // Call callback on animation completion
                self.onAnimationComplete?(true)
            }
        }
    }
    
    // 隐藏面板，带有动画
    // Hide panel with animation
    func hidePanel() {
        // 直接执行隐藏动画，不需要返回等待下一次调用
        // Execute hide animation directly, no need to wait for the next call
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            animationProgress = 0
        } completion: {
            // 动画完成时调用回调
            // Call callback on animation completion
            self.onAnimationComplete?(false)
        }
    }
}

/// Panel controller that manages panel state and transitions
class SlidingPanelController: NSObject {
    // Window reference
    private var window: NSWindow?
    
    // Read-only method to get window reference (for debugging only)
    var hasWindow: Bool {
        return window != nil
    }
    
    // Accessibility service
    private let accessibilityService: AccessibilityService
    
    // Store previous active application
    private var previousActiveApp: NSRunningApplication?
    
    // Keyboard monitor
    private var keyDownEventMonitor: Any?
    
    // AppDelegate reference for status bar access
    private weak var appDelegate: AppDelegate?
    
    // State management using the state machine pattern
    @Published private(set) var panelState: PanelState = .hidden {
        didSet {
            // Notify accessibility service of panel visibility changes
            accessibilityService.setPanelShowing(panelState.isVisible)
            
            // Handle state transitions
            switch (oldValue, panelState) {
            case (_, .hidden) where oldValue != .hidden:
                // Any state -> hidden: Clean up resources
                closeWindowIfNeeded()
                
            case (_, .appearing) where oldValue != .appearing:
                // Any state -> appearing: Create and show window
                // 保存当前活动的应用程序
                // Save the currently active application
                savePreviousActiveApp()
                createAndShowWindow()
                
            case (.appearing, .visible):
                // appearing -> visible: Animation completed
                break
                
            case (_, .disappearing) where oldValue != .disappearing:
                // Any state -> disappearing: Start hiding animation
                startHidingAnimation()
                
            default:
                break
            }
        }
    }
    
    // Backward compatibility property - this will be simplified
    var isVisible: Bool {
        get {
            return panelState.isVisible
        }
        set {
            if newValue && panelState == .hidden {
                requestShowPanel()
            } else if !newValue && panelState != .hidden && !panelState.isTransitioning {
                requestHidePanel()
            }
        }
    }
    
    // 当前应用实体
    // Current application entity
    @Published var currentApplication: ShortcutApplicationEntity?
    
    // 初始化
    // Initialization
    init(appDelegate: AppDelegate? = nil, accessibilityService: AccessibilityService) {
        self.appDelegate = appDelegate
        self.accessibilityService = accessibilityService
        super.init()
    }
    
    // MARK: - Public API
    
    /// Request to show the panel - thread-safe entry point
    func requestShowPanel() {
        guard panelState == .hidden || panelState == .disappearing else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.panelState = .appearing
        }
    }
    
    /// Request to hide the panel - thread-safe entry point
    func requestHidePanel() {
        guard panelState == .visible || panelState == .appearing else { return }
        
        // 直接更改状态，不通过异步队列
        // Change state directly, not via async queue
        panelState = .disappearing
    }
    
    /// Handle panel animation completion callback
    func handleAnimationCompleted(visible: Bool) {
        DispatchQueue.main.async { [weak self] in
            if visible {
                self?.panelState = .visible
            } else {
                self?.panelState = .hidden
            }
        }
    }
    
    // MARK: - Implementation
    
    // Create and show window
    private func createAndShowWindow() {
        guard let currentApplication = currentApplication else {
            panelState = .hidden
            return
        }
        
        // 面板尺寸
        // Panel dimensions
        let panelWidth: CGFloat = 430
        let panelHeight: CGFloat = 700
        
        // 计算屏幕中心位置
        // Calculate screen center position
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowX = screenFrame.width - panelWidth - 20 // 右侧留出20像素边距 // Leave 20px margin on the right
        let windowY = (screenFrame.height - panelHeight) / 2
        
        // 创建和配置窗口
        // Create and configure window
        let sheetWindow = ClickOutsideWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Set window properties
        sheetWindow.backgroundColor = .clear
        sheetWindow.isOpaque = false
        sheetWindow.hasShadow = false
        sheetWindow.ignoresMouseEvents = false
        sheetWindow.acceptsMouseMovedEvents = true
        
        // Set window level to popup menu level (higher)
        sheetWindow.level = .popUpMenu
        
        // Set window behavior to allow overlay on fullscreen apps
        // Note: canJoinAllSpaces and moveToActiveSpace cannot be used together
        sheetWindow.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllApplications]
        
        // Set callback for clicks outside window
        sheetWindow.onClickOutside = { [weak self] in
            print("ClickOutsideWindow: onClickOutside callback triggered")
            self?.requestHidePanel()
        }
        
        // Set status bar click detection logic
        sheetWindow.shouldIgnoreClick = { [weak self] clickPoint in
            // Check if appDelegate is available
            guard let appDelegate = self?.appDelegate else {
                return false
            }
            
            // Get status bar button position and size
            if let statusItem = appDelegate.statusItem, let button = statusItem.button {
                let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
                
                // Check if click is within status bar button area
                let statusItemRect = NSRect(
                    x: buttonFrame.origin.x,
                    y: buttonFrame.origin.y,
                    width: buttonFrame.size.width,
                    height: buttonFrame.size.height
                )
                
                // Ignore click if it's in status bar button area
                if NSPointInRect(clickPoint, statusItemRect) {
                    print("ClickOutsideWindow: Click detected in status bar area - ignoring")
                    return true
                }
            }
            
            // Don't ignore click in other cases
            return false
        }
        
        // Create content view
        let contentView = NSHostingView(
            rootView: SlidingPanelContainer(
                state: Binding<PanelState>(
                    get: { self.panelState },
                    set: { self.panelState = $0 }
                ),
                onAnimationComplete: self.handleAnimationCompleted
            ) {
                ShortcutsView(
                    application: currentApplication
                )
                .frame(width: panelWidth, height: panelHeight)
                .environmentObject(self.appDelegate ?? (NSApp.delegate as! AppDelegate))
            }
        )
        
        contentView.allowedTouchTypes = .indirect
        
        // 设置内容视图
        // Set content view
        sheetWindow.contentView = contentView
        
        // 设置键盘监听 - 监听 ESC 键
        // Set keyboard listener - listen for ESC key
        setupKeyboardMonitor()
        
        // 保存窗口引用
        // Save window reference
        self.window = sheetWindow
        
        // 强制激活窗口
        // Force activate window
        NSApp.activate(ignoringOtherApps: true)
        
        // 尝试直接显示窗口而不是作为子窗口
        // Try to show the window directly instead of as a child window
        sheetWindow.orderFrontRegardless()
        sheetWindow.makeKey()
        
        // 仍然添加为子窗口以保持层级关系
        // Still add as a child window to maintain hierarchy
        if let parent = NSApp.windows.first, parent != sheetWindow {
            print("SlidingPanelController: Adding as child window to \(parent)")
            parent.addChildWindow(sheetWindow, ordered: .above)
        }
        
        // 再次确保窗口获取焦点和激活状态
        // Re-ensure window gets key and activation status
        sheetWindow.makeKeyAndOrderFront(nil)
    }
    
    // 设置键盘监听器
    // Set up keyboard listener
    private func setupKeyboardMonitor() {
        // 移除已有的监听器
        // Remove existing listener
        removeKeyboardMonitor()
        
        // 添加全局键盘事件监听器
        // Add local keyboard event listener
        keyDownEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 检查是否按下 ESC 键 (键码 53)
            // Check if ESC key is pressed (keyCode 53)
            if event.keyCode == 53 {
                self?.requestHidePanel()
                return nil // 消费这个事件 // Consume the event
            }
            return event // 不处理的事件继续传递 // Pass unhandled events
        }
    }
    
    // 移除键盘监听器
    // Remove keyboard listener
    private func removeKeyboardMonitor() {
        if let monitor = keyDownEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownEventMonitor = nil
        }
    }
    
    // 开始隐藏动画
    // Start hiding animation
    private func startHidingAnimation() {
        // 通过通知中心触发隐藏动画
        // Trigger hide animation via NotificationCenter
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("HidePanelRequest"), object: nil)
        }
        
        // 安全机制：如果动画回调没有触发，确保面板最终会隐藏
        // Safety mechanism: Ensure panel hides eventually if animation callback doesn't trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self = self else { return }
            
            // 如果0.7秒后状态仍然是disappearing，强制设置为hidden
            // If state is still disappearing after 0.7s, force set to hidden
            if self.panelState == .disappearing {
                DispatchQueue.main.async {
                    self.panelState = .hidden
                }
            }
        }
    }
    
    // 关闭窗口
    // Close window
    private func closeWindowIfNeeded() {
        guard let window = self.window else { return }
        
        // 移除键盘监听器
        // Remove keyboard listener
        removeKeyboardMonitor()
        
        // 如果是ClickOutsideWindow，移除点击监听器
        // If it's a ClickOutsideWindow, remove the click listener
        if let clickWindow = window as? ClickOutsideWindow {
            clickWindow.onClickOutside = nil
        }
        
        // 延迟关闭窗口，让动画有时间完成
        // Delay closing window to allow animation to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak window] in
            guard let window = window else { return }
            
            window.orderOut(nil)
            self?.window = nil
            
            // 恢复之前的应用程序焦点
            // Restore previous application focus
            self?.restorePreviousAppFocus()
        }
    }
    
    // 设置当前应用并显示面板
    // Set current application and show panel
    func showPanelForApplication(_ application: ShortcutApplicationEntity) {
        // 检查是否已经在显示相同的应用
        // Check if already showing the same application
        if panelState.isVisible && window != nil && currentApplication?.bundleIdentifier == application.bundleIdentifier {
            return
        }
        
        // Set application data
        currentApplication = application
        
        // Request panel to be shown
        DispatchQueue.main.async { [weak self] in
            self?.requestShowPanel()
        }
    }
    
    // 重置面板状态 - 用于解决状态不一致的问题
    // Reset panel state - used to resolve state inconsistencies
    func resetPanelState() {
        // 如果窗口存在但状态为hidden，则关闭窗口
        // If window exists but state is hidden, close the window
        if window != nil && panelState == .hidden {
            closeWindowIfNeeded()
        }
        // 如果窗口不存在但状态不是hidden，则重置状态
        // If window doesn't exist but state is not hidden, reset state
        else if window == nil && panelState != .hidden {
            panelState = .hidden
        }
    }
    
    // 保存当前活动的应用程序
    // Save the currently active application
    private func savePreviousActiveApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            // 确保不保存 KeyFlash 自身
            // Ensure not saving KeyFlash itself
            if frontApp != NSRunningApplication.current {
                previousActiveApp = frontApp
            } else {
                // 尝试获取之前的应用程序
                // Try to get the previous application
                if let apps = NSWorkspace.shared.runningApplications.filter({ 
                    $0 != NSRunningApplication.current && 
                    $0.activationPolicy == .regular 
                }).first {
                    previousActiveApp = apps
                }
            }
        }
    }
    
    // 恢复之前的应用程序焦点
    // Restore previous application focus
    private func restorePreviousAppFocus() {
        if let previousApp = previousActiveApp {
            // 使用短暂延迟确保窗口已完全关闭
            // Use a short delay to ensure the window is fully closed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !previousApp.isTerminated {
                    previousApp.activate(options: [.activateIgnoringOtherApps])
                }
            }
            
            // 清除引用
            // Clear the reference
            previousActiveApp = nil
        }
    }
}

// MARK: - Helper Views

// 毛玻璃效果视图
// Visual effect view (blur)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// MARK: - Animation Completion Extension

extension View {
    /// Adds a completion handler to a SwiftUI animation
    func onAnimationCompleted<Value: VectorArithmetic>(for value: Value, completion: @escaping () -> Void) -> ModifiedContent<Self, AnimationCompletionObserverModifier<Value>> {
        return modifier(AnimationCompletionObserverModifier(observedValue: value, completion: completion))
    }
}

/// A modifier that observes an animating value and executes a completion handler when the animation completes
struct AnimationCompletionObserverModifier<Value: VectorArithmetic>: ViewModifier {
    let observedValue: Value
    let completion: () -> Void
    
    @State private var prevValue: Value?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: observedValue) { newValue in
                guard prevValue != nil else {
                    prevValue = newValue
                    return
                }
                
                if newValue == prevValue {
                    DispatchQueue.main.async {
                        self.completion()
                    }
                }
                
                prevValue = newValue
            }
    }
}

// MARK: - Preview

struct SlidingPanelContainer_Previews: PreviewProvider {
    static var previews: some View {
        SlidingPanelContainer(state: .constant(.visible)) {
            Text("Sliding Panel Content")
                .frame(width: 430, height: 700)
                .background(Color.white)
        }
    }
}

