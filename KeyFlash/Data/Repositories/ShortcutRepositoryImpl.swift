import Foundation
import Combine
import os.log

/// 快捷键仓库实现，实现快捷键存储和检索接口
/// Shortcut repository implementation, implements the shortcut storage and retrieval interface
class ShortcutRepositoryImpl: ShortcutRepository {
    // MARK: - Properties
    
    /// 日志记录器
    /// Logger
    private let logger = Logger(subsystem: "com.easytime.keyflash", category: "ShortcutRepositoryImpl")
    
    // 是否启用详细日志
    // Whether detailed logging is enabled
    private let debugMode = true
    
    // 快捷键缓存
    // Shortcut cache
    private let shortcutCache: ShortcutCache
    
    // 默认缓存过期时间（秒）
    // Default cache expiration time (seconds)
    private let defaultMaxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Initialization
    
    init(shortcutCache: ShortcutCache = ShortcutCache.shared) {
        self.shortcutCache = shortcutCache
        logDebug("ShortcutRepositoryImpl Initialization") // Initialization
    }
    
    // MARK: - ShortcutRepository Implementation
    
    func saveApplicationShortcuts(_ application: ApplicationEntity) -> AnyPublisher<Void, Error> {
        logDebug("Saving application shortcuts: \(application.name) (\(application.bundleIdentifier))") // Saving application shortcuts:
        logDebug("Menu item count: \(application.menuItems.count)") // Menu item count:
        
        // 转换为数据模型
        // Convert to data model
        let applicationModel = ApplicationModel(from: application)
        
        // 保存到缓存
        // Save to cache
        return shortcutCache.saveApplication(applicationModel)
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Failed to save application shortcuts: \(error.localizedDescription)") // Failed to save application shortcuts:
                    } else {
                        self?.logDebug("Successfully saved application shortcuts") // Successfully saved application shortcuts
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func getApplicationShortcuts(bundleIdentifier: String) -> AnyPublisher<ApplicationEntity?, Error> {
        logDebug("Getting application shortcuts: \(bundleIdentifier)") // Getting application shortcuts:
        
        return shortcutCache.getApplication(bundleIdentifier: bundleIdentifier)
            .map { applicationModel -> ApplicationEntity? in
                guard let applicationModel = applicationModel else {
                    self.logDebug("Application cache not found: \(bundleIdentifier)") // Application cache not found:
                    return nil
                }
                
                let applicationEntity = applicationModel.toEntity()
                self.logDebug("Successfully retrieved application shortcuts: \(applicationEntity.name), Menu item count: \(applicationEntity.menuItems.count)") // Successfully retrieved application shortcuts: ..., Menu item count: ...
                return applicationEntity
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Failed to get application shortcuts: \(error.localizedDescription)") // Failed to get application shortcuts:
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func getAllCachedApplications() -> AnyPublisher<[ApplicationEntity], Error> {
        logDebug("Getting all cached applications") // Getting all cached applications
        
        return shortcutCache.getAllApplications()
            .map { applicationModels -> [ApplicationEntity] in
                let applicationEntities = applicationModels.map { $0.toEntity() }
                self.logDebug("Successfully retrieved all cached applications, total \(applicationEntities.count) apps") // Successfully retrieved all cached applications, total ... apps
                return applicationEntities
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Failed to get all cached applications: \(error.localizedDescription)") // Failed to get all cached applications:
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func deleteApplicationCache(bundleIdentifier: String) -> AnyPublisher<Void, Error> {
        logDebug("Deleting application cache: \(bundleIdentifier)") // Deleting application cache:
        
        return shortcutCache.deleteApplication(bundleIdentifier: bundleIdentifier)
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Failed to delete application cache: \(error.localizedDescription)") // Failed to delete application cache:
                    } else {
                        self?.logDebug("Successfully deleted application cache") // Successfully deleted application cache
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func clearAllCache() -> AnyPublisher<Void, Error> {
        logDebug("Clearing all cache") // Clearing all cache
        
        return shortcutCache.clearAllCache()
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Failed to clear all cache: \(error.localizedDescription)") // Failed to clear all cache:
                    } else {
                        self?.logDebug("Successfully cleared all cache") // Successfully cleared all cache
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func isCacheStale(bundleIdentifier: String, maxAge: TimeInterval = 0) -> AnyPublisher<Bool, Error> {
        let cacheAge = maxAge > 0 ? maxAge : defaultMaxCacheAge
        logDebug("Checking if application cache is stale: \(bundleIdentifier), Max cache age: \(cacheAge) seconds") // Checking if application cache is stale: ..., Max cache age: ... seconds
        
        return shortcutCache.isCacheStale(bundleIdentifier: bundleIdentifier, maxAge: cacheAge)
            .handleEvents(
                receiveOutput: { [weak self] isStale in
                    self?.logDebug("Application cache status: \(bundleIdentifier) \(isStale ? "is stale" : "is not stale")") // Application cache status: ...
                },
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.logDebug("Failed to check application cache status: \(error.localizedDescription)") // Failed to check application cache status:
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    // MARK: - Logging
    
    private func logDebug(_ message: String) {
        if debugMode {
            logger.debug("\(message)")
            print("[ShortcutRepositoryImpl] \(message)")
        }
    }
} 