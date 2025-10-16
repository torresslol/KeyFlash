import Cocoa

/// 监控全局事件的辅助类
/// Helper class for monitoring global events
class EventMonitor {
    /// 事件处理函数类型，接收一个NSEvent，可选返回一个NSEvent
    /// Event handler function type, receives an NSEvent, optionally returns an NSEvent
    typealias EventHandler = (NSEvent?) -> NSEvent?
    
    /// 要监控的事件类型
    /// The type of events to monitor
    private let mask: NSEvent.EventTypeMask
    
    /// 是否为本地监控器
    /// Whether it is a local monitor
    private let isLocalMonitor: Bool
    
    /// 事件处理函数
    /// Event handler function
    private let handler: EventHandler
    
    /// 监控器引用
    /// Monitor reference
    private var monitor: Any?
    
    /// 初始化事件监控器
    /// Initializes the event monitor
    /// - Parameters:
    ///   - mask: 要监控的事件类型 // The type of events to monitor
    ///   - isLocalMonitor: 是否为本地监控器，默认为false（全局监控器） // Whether it is a local monitor, defaults to false (global monitor)
    ///   - handler: 事件处理函数 // Event handler function
    init(mask: NSEvent.EventTypeMask, isLocalMonitor: Bool = false, handler: @escaping EventHandler) {
        self.mask = mask
        self.isLocalMonitor = isLocalMonitor
        self.handler = handler
    }
    
    /// 析构函数
    /// Deinitializer
    deinit {
        stop()
    }
    
    /// 开始监控事件
    /// Start monitoring events
    func start() {
        if isLocalMonitor {
            monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
        } else {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                guard let self = self else { return }
                _ = self.handler(event)
            }
        }
    }
    
    /// 停止监控事件
    /// Stop monitoring events
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
} 