import SwiftUI
import Combine

/// 支持鼠标拖动滚动的ScrollView
/// ScrollView that supports scrolling by mouse dragging
struct DraggableScrollView<Content: View>: View {
    // MARK: - 属性
    // MARK: - Properties
    var axes: Axis.Set = [.vertical]
    var showsIndicators: Bool = true
    var speedFactor: CGFloat = 1.0
    var momentumDecreaseFactor: CGFloat = 0.94
    var minimumVelocity: CGFloat = 5.0
    var inertiaEnabled: Bool = true
    var content: () -> Content
    
    // MARK: - 初始化
    // MARK: - Initialization
    init(
        axes: Axis.Set = [.vertical],
        showsIndicators: Bool = true,
        speedFactor: CGFloat = 1.0,
        momentumDecreaseFactor: CGFloat = 0.94,
        minimumVelocity: CGFloat = 5.0,
        inertiaEnabled: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.speedFactor = speedFactor
        self.momentumDecreaseFactor = momentumDecreaseFactor
        self.minimumVelocity = minimumVelocity
        self.inertiaEnabled = inertiaEnabled
        self.content = content
    }
    
    // MARK: - 视图主体
    // MARK: - View Body
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
        }
        .modifier(MouseDragScrollModifier(
            speedFactor: speedFactor,
            momentumDecreaseFactor: momentumDecreaseFactor,
            minimumVelocity: minimumVelocity,
            inertiaEnabled: inertiaEnabled
        ))
    }
}

// MARK: - 鼠标拖动修饰符
// MARK: - Mouse Drag Modifier
fileprivate struct MouseDragScrollModifier: ViewModifier {
    // 状态跟踪
    // State tracking
    @State private var dragStarted = false
    @State private var lastTranslation = CGSize.zero
    @State private var velocity = CGSize.zero
    @State private var lastUpdateTime = Date()
    @State private var momentumTimer: Timer?
    
    // 配置参数
    // Configuration parameters
    let speedFactor: CGFloat
    let momentumDecreaseFactor: CGFloat
    let minimumVelocity: CGFloat
    let inertiaEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        // 计算从上次更新到现在的增量
                        // Calculate the delta since the last update
                        let deltaX = value.translation.width - lastTranslation.width
                        let deltaY = value.translation.height - lastTranslation.height
                        
                        // 更新速度
                        // Update velocity
                        let now = Date()
                        let timeDelta = now.timeIntervalSince(lastUpdateTime)
                        
                        if !dragStarted {
                            dragStarted = true
                            // 取消当前的动量计时器
                            // Cancel the current momentum timer
                            momentumTimer?.invalidate()
                        } else if timeDelta > 0 {
                            // 平滑速度计算
                            // Smooth velocity calculation
                            velocity.width = velocity.width * 0.7 + (deltaX / CGFloat(timeDelta)) * 0.3
                            velocity.height = velocity.height * 0.7 + (deltaY / CGFloat(timeDelta)) * 0.3
                        }
                        
                        // 发送滚动事件
                        // Send scroll event
                        sendScrollEvent(deltaX: deltaX * speedFactor, deltaY: deltaY * speedFactor)
                        
                        // 更新状态
                        // Update state
                        lastTranslation = value.translation
                        lastUpdateTime = now
                    }
                    .onEnded { _ in
                        // 结束拖动
                        // End dragging
                        dragStarted = false
                        
                        // 如果启用惯性滚动并且有足够的速度，开始动量滚动
                        // If inertia scrolling is enabled and there is sufficient velocity, start momentum scrolling
                        if inertiaEnabled && (abs(velocity.width) > minimumVelocity || abs(velocity.height) > minimumVelocity) {
                            startMomentum()
                        }
                        
                        // 重置状态
                        // Reset state
                        lastTranslation = .zero
                    }
            )
    }
    
    // 发送滚动事件到系统
    // Send scroll event to the system
    private func sendScrollEvent(deltaX: CGFloat, deltaY: CGFloat) {
        let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, 
                                 units: .pixel, 
                                 wheelCount: 2, 
                                 wheel1: Int32(deltaY),  // 内容跟随鼠标移动方向 // Content follows mouse movement direction
                                 wheel2: Int32(deltaX),  // 内容跟随鼠标移动方向 // Content follows mouse movement direction
                                 wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }
    
    // 开始惯性滚动
    // Start inertia scrolling
    private func startMomentum() {
        // 取消之前的定时器
        // Cancel the previous timer
        momentumTimer?.invalidate()
        
        // 创建新的惯性滚动定时器
        // Create a new inertia scroll timer
        momentumTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            // 减少速度
            // Decrease velocity
            velocity.width *= momentumDecreaseFactor
            velocity.height *= momentumDecreaseFactor
            
            // 如果速度足够小，停止滚动
            // If velocity is small enough, stop scrolling
            if abs(velocity.width) < minimumVelocity && abs(velocity.height) < minimumVelocity {
                timer.invalidate()
                return
            }
            
            // 发送滚动事件
            // Send scroll event
            let deltaX = velocity.width / 60
            let deltaY = velocity.height / 60
            
            sendScrollEvent(deltaX: deltaX, deltaY: deltaY)
        }
        
        // 确保定时器在所有RunLoop模式下运行
        // Ensure the timer runs in all RunLoop modes
        if let timer = momentumTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
} 