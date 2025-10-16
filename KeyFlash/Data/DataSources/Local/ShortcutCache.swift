import Foundation
import Combine
import os.log

/// 快捷键缓存类，管理快捷键内存和磁盘缓存
/// Shortcut cache class, manages memory and disk cache for shortcuts
class ShortcutCache {
    // MARK: - Properties
    
    // 单例实例
    // Singleton instance
    static let shared = ShortcutCache()
    
    /// 日志记录器
    /// Logger
    private let logger = Logger(subsystem: "com.easytime.keyflash", category: "ShortcutCache")
    
    // 是否启用详细日志
    // Whether detailed logging is enabled
    private let debugMode = true
    
    // 内存缓存
    // Memory cache
    private var memoryCache: [String: ApplicationModel] = [:]
    
    /// 缓存目录 URL
    /// Cache directory URL
    private let cacheDirectoryURL: URL
    
    // 缓存文件扩展名
    // Cache file extension
    private let cacheFileExtension = "json"
    
    // 缓存过期时间（默认24小时）
    // Cache expiration time (default 24 hours)
    private let defaultCacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    /// 序列化队列
    /// Serialization queue
    private let serializationQueue = DispatchQueue(label: "com.easytime.keyflash.cache.serialization", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        // 获取缓存目录
        // Get cache directory
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectoryURL = cachesDirectory.appendingPathComponent("com.easytime.keyflash/shortcuts", isDirectory: true)
        
        // 创建缓存目录，处理错误
        // Create cache directory, handle errors
        do {
            try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
            logDebug("Cache directory ensured exists: \(cacheDirectoryURL.path)") // Cache directory ensured exists:
        } catch {
            logger.error("Failed to create cache directory: \(error.localizedDescription)") // Failed to create cache directory:
            // 即使目录创建失败，也尝试继续，但可能无法保存缓存
            // Even if directory creation fails, try to continue, but caching might not work
        }
        
        // 加载所有缓存到内存
        // Load all cache into memory
        loadAllCacheFromDisk()
    }
    
    // MARK: - Public Methods
    
    /// 保存应用程序快捷键到缓存
    /// Saves application shortcuts to cache
    /// - Parameter applicationModel: 应用程序数据模型 // Application data model
    /// - Returns: 保存操作完成的Publisher // Publisher that completes when the save operation is done
    func saveApplication(_ applicationModel: ApplicationModel) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CacheError.internalError))
                return
            }
            
            self.serializationQueue.async {
                do {
                    // 保存到内存缓存
                    // Save to memory cache
                    self.memoryCache[applicationModel.bundleIdentifier] = applicationModel
                    self.logDebug("Application \(applicationModel.name) saved to memory cache") // Application ... saved to memory cache
                    
                    // 保存到磁盘缓存
                    // Save to disk cache
                    try self.saveToDisk(applicationModel)
                    self.logDebug("Application \(applicationModel.name) saved to disk cache") // Application ... saved to disk cache
                    
                    // 完成
                    // Complete
                    DispatchQueue.main.async {
                        promise(.success(()))
                    }
                } catch {
                    self.logDebug("Failed to save application \(applicationModel.name) to disk cache: \(error.localizedDescription)") // Failed to save application ... to disk cache:
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// 从缓存获取应用程序快捷键
    /// Gets application shortcuts from cache
    /// - Parameter bundleIdentifier: 应用程序的捆绑包标识符 // Application's bundle identifier
    /// - Returns: 包含应用快捷键数据的Publisher // Publisher containing application shortcut data
    func getApplication(bundleIdentifier: String) -> AnyPublisher<ApplicationModel?, Error> {
        return Future<ApplicationModel?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CacheError.internalError))
                return
            }
            
            self.serializationQueue.async {
                // 优先从内存缓存获取
                // Prioritize getting from memory cache
                if let applicationModel = self.memoryCache[bundleIdentifier] {
                    self.logDebug("Successfully retrieved application \(bundleIdentifier) from memory cache") // Successfully retrieved application ... from memory cache
                    DispatchQueue.main.async {
                        promise(.success(applicationModel))
                    }
                    return
                }
                
                // 从磁盘缓存获取
                // Get from disk cache
                do {
                    let applicationModel = try self.loadFromDisk(bundleIdentifier: bundleIdentifier)
                    
                    if let applicationModel = applicationModel {
                        // 保存到内存缓存
                        // Save to memory cache
                        self.memoryCache[bundleIdentifier] = applicationModel
                        self.logDebug("Successfully retrieved application \(bundleIdentifier) from disk cache and loaded to memory") // Successfully retrieved application ... from disk cache and loaded to memory
                    } else {
                        self.logDebug("Application \(bundleIdentifier) does not exist in cache") // Application ... does not exist in cache
                    }
                    
                    DispatchQueue.main.async {
                        promise(.success(applicationModel))
                    }
                } catch {
                    self.logDebug("Failed to get application \(bundleIdentifier) from disk cache: \(error.localizedDescription)") // Failed to get application ... from disk cache:
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// 获取所有缓存的应用程序
    /// Gets all cached applications
    /// - Returns: 包含所有应用数据模型的Publisher // Publisher containing all application data models
    func getAllApplications() -> AnyPublisher<[ApplicationModel], Error> {
        return Future<[ApplicationModel], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CacheError.internalError))
                return
            }
            
            self.serializationQueue.async {
                do {
                    // 从磁盘加载所有缓存
                    // Load all caches from disk
                    let applications = try self.loadAllApplicationsFromDisk()
                    self.logDebug("Loaded \(applications.count) application caches from disk") // Loaded ... application caches from disk
                    
                    DispatchQueue.main.async {
                        promise(.success(applications))
                    }
                } catch {
                    self.logDebug("Failed to load all application caches: \(error.localizedDescription)") // Failed to load all application caches:
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// 删除指定应用程序的缓存
    /// Deletes the cache for a specific application
    /// - Parameter bundleIdentifier: 应用程序的捆绑包标识符 // Application's bundle identifier
    /// - Returns: 删除操作完成的Publisher // Publisher that completes when the delete operation is done
    func deleteApplication(bundleIdentifier: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CacheError.internalError))
                return
            }
            
            self.serializationQueue.async {
                do {
                    // 从内存缓存删除
                    // Delete from memory cache
                    self.memoryCache.removeValue(forKey: bundleIdentifier)
                    
                    // 从磁盘缓存删除
                    // Delete from disk cache
                    let fileURL = self.getCacheFileURL(for: bundleIdentifier)
                    
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                        self.logDebug("Deleted cache file for application \(bundleIdentifier)") // Deleted cache file for application ...
                    } else {
                        self.logDebug("Cache file for application \(bundleIdentifier) does not exist") // Cache file for application ... does not exist
                    }
                    
                    DispatchQueue.main.async {
                        promise(.success(()))
                    }
                } catch {
                    self.logDebug("Failed to delete cache for application \(bundleIdentifier): \(error.localizedDescription)") // Failed to delete cache for application ...:
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// 清除所有缓存
    /// Clears all cache
    /// - Returns: 清除操作完成的Publisher // Publisher that completes when the clear operation is done
    func clearAllCache() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CacheError.internalError))
                return
            }
            
            self.serializationQueue.async {
                do {
                    // 清空内存缓存
                    // Clear memory cache
                    self.memoryCache.removeAll()
                    
                    // 清空磁盘缓存
                    // Clear disk cache
                    let fileManager = FileManager.default
                    
                    // 获取缓存目录中的所有文件
                    // Get all files in the cache directory
                    let fileURLs = try fileManager.contentsOfDirectory(
                        at: self.cacheDirectoryURL,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                    
                    // 删除所有缓存文件
                    // Delete all cache files
                    for fileURL in fileURLs {
                        try fileManager.removeItem(at: fileURL)
                    }
                    
                    self.logDebug("Cleared all cache, total \(fileURLs.count) files") // Cleared all cache, total ... files
                    
                    DispatchQueue.main.async {
                        promise(.success(()))
                    }
                } catch {
                    self.logDebug("Failed to clear all cache: \(error.localizedDescription)") // Failed to clear all cache:
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// 检查应用程序缓存是否已过期
    /// Checks if the application cache is expired
    /// - Parameters:
    ///   - bundleIdentifier: 应用程序的捆绑包标识符 // Application's bundle identifier
    ///   - maxAge: 最大缓存有效期（秒），默认为24小时 // Maximum cache age (seconds), default 24 hours
    /// - Returns: 布尔值表示是否已过期 // Boolean indicating if expired
    func isCacheStale(bundleIdentifier: String, maxAge: TimeInterval = 0) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CacheError.internalError))
                return
            }
            
            let expirationInterval = maxAge > 0 ? maxAge : self.defaultCacheExpirationInterval
            
            self.serializationQueue.async {
                do {
                    // 优先从内存缓存检查
                    // Prioritize checking memory cache
                    if let applicationModel = self.memoryCache[bundleIdentifier] {
                        let isStale = Date().timeIntervalSince(applicationModel.lastRefreshTime) > expirationInterval
                        self.logDebug("Application \(bundleIdentifier) in memory cache is \(isStale ? "stale" : "not stale")") // Application ... in memory cache is ...
                        DispatchQueue.main.async {
                            promise(.success(isStale))
                        }
                        return
                    }
                    
                    // 从磁盘缓存检查
                    // Check disk cache
                    let fileURL = self.getCacheFileURL(for: bundleIdentifier)
                    
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let applicationModel = try self.loadFromDisk(bundleIdentifier: bundleIdentifier)
                        
                        if let applicationModel = applicationModel {
                            let isStale = Date().timeIntervalSince(applicationModel.lastRefreshTime) > expirationInterval
                            self.logDebug("Application \(bundleIdentifier) in disk cache is \(isStale ? "stale" : "not stale")") // Application ... in disk cache is ...
                            DispatchQueue.main.async {
                                promise(.success(isStale))
                            }
                        } else {
                            // 缓存文件存在但无法加载，视为过期
                            // Cache file exists but cannot be loaded, consider it stale
                            self.logDebug("Cache file for application \(bundleIdentifier) exists but could not be loaded, considering stale") // Cache file for application ... exists but could not be loaded, considering stale
                            DispatchQueue.main.async {
                                promise(.success(true))
                            }
                        }
                    } else {
                        // 缓存不存在，视为过期
                        // Cache does not exist, consider it stale
                        self.logDebug("Cache for application \(bundleIdentifier) does not exist, considering stale") // Cache for application ... does not exist, considering stale
                        DispatchQueue.main.async {
                            promise(.success(true))
                        }
                    }
                } catch {
                    self.logDebug("Failed to check if application \(bundleIdentifier) cache is stale: \(error.localizedDescription)") // Failed to check if application ... cache is stale:
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /// 保存应用程序数据模型到磁盘
    /// Saves application data model to disk
    private func saveToDisk(_ applicationModel: ApplicationModel) throws {
        // 确保缓存目录存在
        // Ensure cache directory exists
        createCacheDirectoryIfNeeded()
        
        // 获取缓存文件路径
        // Get cache file path
        let fileURL = getCacheFileURL(for: applicationModel.bundleIdentifier)
        
        // 如果已存在旧文件，先删除
        // If an old file exists, delete it first
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            logDebug("Deleted old cache file: \(fileURL.lastPathComponent)") // Deleted old cache file:
        }
        
        // 编码为JSON数据
        // Encode to JSON data
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(applicationModel)
        
        // 写入文件
        // Write to file
        try data.write(to: fileURL, options: .atomic)
        logDebug("Saved new cache file: \(fileURL.lastPathComponent)") // Saved new cache file:
    }
    
    /// 从磁盘加载应用程序数据模型
    /// Loads application data model from disk
    private func loadFromDisk(bundleIdentifier: String) throws -> ApplicationModel? {
        let fileURL = getCacheFileURL(for: bundleIdentifier)
        
        // 检查文件是否存在
        // Check if file exists
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return nil
        }
        
        // 读取文件数据
        // Read file data
        let data = try Data(contentsOf: fileURL)
        
        // 解码JSON数据
        // Decode JSON data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(ApplicationModel.self, from: data)
    }
    
    /// 从磁盘加载所有应用程序数据模型
    /// Loads all application data models from disk
    private func loadAllApplicationsFromDisk() throws -> [ApplicationModel] {
        // 确保缓存目录存在
        // Ensure cache directory exists
        createCacheDirectoryIfNeeded()
        
        // 获取缓存目录中的所有文件
        // Get all files in the cache directory
        let fileManager = FileManager.default
        let fileURLs = try fileManager.contentsOfDirectory(
            at: cacheDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        // 筛选JSON文件
        // Filter JSON files
        let jsonFileURLs = fileURLs.filter { $0.pathExtension == cacheFileExtension }
        
        var applications: [ApplicationModel] = []
        var processedBundleIds = Set<String>() // 用于跟踪已处理的 bundleId // Used to track processed bundleIds
        
        // 解码所有缓存文件
        // Decode all cache files
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 按文件修改时间排序，保证加载最新的缓存
        // Sort by file modification date to ensure loading the latest cache
        let sortedURLs = try jsonFileURLs.sorted { file1, file2 in
            let attr1 = try FileManager.default.attributesOfItem(atPath: file1.path)
            let attr2 = try FileManager.default.attributesOfItem(atPath: file2.path)
            let date1 = attr1[.modificationDate] as? Date ?? Date.distantPast
            let date2 = attr2[.modificationDate] as? Date ?? Date.distantPast
            return date1 > date2
        }
        
        for fileURL in sortedURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let application = try decoder.decode(ApplicationModel.self, from: data)
                
                // 如果这个 bundleId 已经处理过，删除旧文件并跳过
                // If this bundleId has already been processed, delete the old file and skip
                if processedBundleIds.contains(application.bundleIdentifier) {
                    try? FileManager.default.removeItem(at: fileURL)
                    logDebug("Deleted duplicate cache file: \(fileURL.lastPathComponent)") // Deleted duplicate cache file:
                    continue
                }
                
                applications.append(application)
                processedBundleIds.insert(application.bundleIdentifier)
                
                // 更新内存缓存
                // Update memory cache
                memoryCache[application.bundleIdentifier] = application
                
            } catch {
                logDebug("Failed to load cache file \(fileURL.lastPathComponent): \(error.localizedDescription)") // Failed to load cache file ...:
                // 删除无效的缓存文件
                // Delete invalid cache file
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }
        }
        
        logDebug("Successfully loaded \(applications.count) unique application caches") // Successfully loaded ... unique application caches
        return applications
    }
    
    /// 加载所有缓存到内存
    /// Loads all cache into memory
    private func loadAllCacheFromDisk() {
        serializationQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let applications = try self.loadAllApplicationsFromDisk()
                
                // 更新内存缓存
                // Update memory cache
                for application in applications {
                    self.memoryCache[application.bundleIdentifier] = application
                }
                
                self.logDebug("Loaded \(applications.count) application caches into memory") // Loaded ... application caches into memory
            } catch {
                self.logDebug("Failed to load cache into memory: \(error.localizedDescription)") // Failed to load cache into memory:
            }
        }
    }
    
    /// 获取缓存文件URL
    /// Gets the cache file URL
    private func getCacheFileURL(for bundleIdentifier: String) -> URL {
        // 将捆绑包标识符处理为安全的文件名
        // Process the bundle identifier into a safe filename
        let safeFileName = bundleIdentifier.replacingOccurrences(of: ".", with: "_")
        return cacheDirectoryURL.appendingPathComponent("\(safeFileName).\(cacheFileExtension)")
    }
    
    /// 创建缓存目录（如果不存在）
    /// Creates the cache directory (if it doesn't exist)
    private func createCacheDirectoryIfNeeded() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            do {
                try fileManager.createDirectory(
                    at: cacheDirectoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logDebug("Created cache directory: \(cacheDirectoryURL.path)") // Created cache directory:
            } catch {
                logDebug("Failed to create cache directory: \(error.localizedDescription)") // Failed to create cache directory:
            }
        }
    }
    
    // MARK: - Logging
    
    private func logDebug(_ message: String) {
        if debugMode {
            logger.debug("\(message)")
            print("[ShortcutCache] \(message)")
        }
    }
}

// MARK: - Errors

enum CacheError: Error {
    case serializationFailed
    case deserializationFailed
    case fileOperationFailed
    case cacheNotFound
    case internalError
    
    var localizedDescription: String {
        switch self {
        case .serializationFailed:
            return "Failed to serialize application data."
        case .deserializationFailed:
            return "Failed to deserialize application data."
        case .fileOperationFailed:
            return "File operation failed."
        case .cacheNotFound:
            return "Could not find the requested cache data."
        case .internalError:
            return "Internal error."
        }
    }
} 