import Foundation
import Combine

/// 快捷键仓库接口，定义快捷键存储和检索接口
/// Shortcut repository interface, defines the interface for storing and retrieving shortcuts
protocol ShortcutRepository {
    /// 保存应用程序快捷键数据
    /// Saves application shortcut data
    /// - Parameter application: 包含快捷键数据的应用实体 // Application entity containing shortcut data
    /// - Returns: 保存操作完成的Publisher // Publisher that completes when the save operation is done
    func saveApplicationShortcuts(_ application: ApplicationEntity) -> AnyPublisher<Void, Error>
    
    /// 获取指定应用程序的快捷键数据
    /// Gets shortcut data for a specific application
    /// - Parameter bundleIdentifier: 应用程序的捆绑包标识符 // Application's bundle identifier
    /// - Returns: 包含应用快捷键数据的Publisher // Publisher containing the application shortcut data
    func getApplicationShortcuts(bundleIdentifier: String) -> AnyPublisher<ApplicationEntity?, Error>
    
    /// 获取所有已缓存的应用程序
    /// Gets all cached applications
    /// - Returns: 包含所有应用实体的Publisher // Publisher containing all application entities
    func getAllCachedApplications() -> AnyPublisher<[ApplicationEntity], Error>
    
    /// 根据捆绑包标识符删除应用程序缓存
    /// Deletes application cache by bundle identifier
    /// - Parameter bundleIdentifier: 应用程序的捆绑包标识符 // Application's bundle identifier
    /// - Returns: 删除操作完成的Publisher // Publisher that completes when the delete operation is done
    func deleteApplicationCache(bundleIdentifier: String) -> AnyPublisher<Void, Error>
    
    /// 清除所有缓存
    /// Clears all cache
    /// - Returns: 清除操作完成的Publisher // Publisher that completes when the clear operation is done
    func clearAllCache() -> AnyPublisher<Void, Error>
    
    /// 检查应用程序缓存是否需要刷新
    /// Checks if the application cache needs refreshing
    /// - Parameters:
    ///   - bundleIdentifier: 应用程序的捆绑包标识符 // Application's bundle identifier
    ///   - maxAge: 最大缓存有效期（秒） // Maximum cache age (seconds)
    /// - Returns: 布尔值表示是否需要刷新 // Boolean indicating if refresh is needed
    func isCacheStale(bundleIdentifier: String, maxAge: TimeInterval) -> AnyPublisher<Bool, Error>
} 