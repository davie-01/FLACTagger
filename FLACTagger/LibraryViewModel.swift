import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

// ============================================================
// LibraryViewModel.swift
// 音乐库视图模型：管理所有已导入的 FLAC 文件列表
// 负责文件导入、扫描、搜索筛选、批量操作等核心逻辑
// 使用 @MainActor 确保 UI 更新都在主线程执行
// ============================================================

class LibraryViewModel: ObservableObject {
    
    // MARK: - 已导入的所有 FLAC 文件列表
    @Published var tracks: [FLACTrack] = []
    
    // MARK: - 当前选中的文件
    @Published var selectedTrack: FLACTrack? = nil
    
    // MARK: - 多选支持
    @Published var selectedIDs: Set<FLACTrack.ID> = []  // 当前选中的所有文件 ID
    @Published var showDetailPanel: Bool = false          // 是否显示详情面板（双击或右键详情触发）
    @Published var detailTrack: FLACTrack? = nil          // 详情面板显示的文件
    
    // MARK: - 侧边栏当前选中的筛选分类
    @Published var sidebarFilter: SidebarFilter = .all
    
    // MARK: - 搜索关键词
    @Published var searchText: String = ""
    
    // MARK: - 排序方式
    @Published var sortKey: SortKey = .title
    @Published var sortAscending: Bool = true
    
    // MARK: - 批量操作进度
    @Published var isBatchProcessing: Bool = false  // 是否正在批量处理
    @Published var batchProgress: Double = 0.0      // 进度 0.0 - 1.0
    @Published var batchLog: [BatchLogEntry] = []   // 批量操作日志
    @Published var showBatchPanel: Bool = false      // 是否显示日志面板
    
    // MARK: - 错误提示
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false
    
    // MARK: - 应用设置（共享单例）
    let settings = AppSettings.shared
    
    // MARK: - 经过筛选和搜索后的文件列表（供 UI 显示）
    var filteredTracks: [FLACTrack] {
        var result = tracks
        
        // 1. 按侧边栏分类筛选
        switch sidebarFilter {
        case .all:       break // 不过滤
        case .noCover:   result = result.filter { $0.missingCover }
        case .noLyrics:  result = result.filter { $0.missingLyrics }
        case .noArtist:  result = result.filter { $0.missingArtist }
        case .notSynced: result = result.filter { $0.coverNotSynced }
        }
        
        // 2. 按搜索关键词过滤（同时匹配标题和艺术家）
        if !searchText.isEmpty {
            let keyword = searchText.lowercased()
            result = result.filter {
                $0.displayTitle.lowercased().contains(keyword) ||
                $0.artist.lowercased().contains(keyword)
            }
        }
        
        // 3. 排序
        result.sort { a, b in
            let compare: Bool
            switch sortKey {
            case .title:  compare = a.displayTitle < b.displayTitle
            case .artist: compare = a.artist < b.artist
            case .album:  compare = a.album < b.album
            case .year:   compare = a.year < b.year
            case .size:   compare = a.fileSize < b.fileSize
            }
            return sortAscending ? compare : !compare
        }
        
        return result
    }
    
    // MARK: - 各筛选分类的数量（用于侧边栏显示角标）
    var allCount: Int       { tracks.count }
    var noCoverCount: Int   { tracks.filter { $0.missingCover }.count }
    var noLyricsCount: Int  { tracks.filter { $0.missingLyrics }.count }
    var noArtistCount: Int  { tracks.filter { $0.missingArtist }.count }
    var notSyncedCount: Int { tracks.filter { $0.coverNotSynced }.count }
    
    // MARK: - 导入文件或文件夹（优化版：先显示列表再后台解析）
    func importURLs(_ urls: [URL]) {
        Task { @MainActor in
            var newTracks: [FLACTrack] = []
            
            for url in urls {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                if isDir.boolValue {
                    newTracks += collectFLACFiles(in: url)
                } else if url.pathExtension.lowercased() == "flac" {
                    newTracks.append(FLACTrack(url: url))
                }
            }
            
            // 去重
            let existingPaths = Set(tracks.map { $0.url.path })
            let uniqueNew = newTracks.filter { !existingPaths.contains($0.url.path) }
            guard !uniqueNew.isEmpty else { return }
            
            // 立即显示文件列表（不等解析完成）
            tracks += uniqueNew
            

            
            // 逐个解析，在主线程执行避免并发问题
            for (index, track) in uniqueNew.enumerated() {
                FLACParser.parse(track: track)
                // 每解析 20 个让 UI 刷新一次
                if index % 20 == 0 {
                    await Task.yield()
                }
            }
        }
    }
    
    // MARK: - 打开文件选择面板
    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "flac") ?? .audio,
            .folder
        ]
        panel.title = "选择 FLAC 文件或文件夹"
        panel.prompt = "导入"
        
        if panel.runModal() == .OK {
            importURLs(panel.urls)
        }
    }
    
    // MARK: - 递归扫描文件夹收集 FLAC 文件
    private func collectFLACFiles(in dir: URL) -> [FLACTrack] {
        let options: FileManager.DirectoryEnumerationOptions = settings.scanSubdirectories
            ? [.skipsHiddenFiles]
            : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) else { return [] }
        
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension.lowercased() == "flac" }
            .map { FLACTrack(url: $0) }
    }
    
    // MARK: - 在 Finder 中显示文件
    func revealInFinder(_ track: FLACTrack) {
        NSWorkspace.shared.activateFileViewerSelecting([track.url])
    }
    
    // MARK: - 从列表中移除文件（不删除磁盘文件）
    func removeTrack(_ track: FLACTrack) {
        tracks.removeAll { $0.id == track.id }
        if selectedTrack?.id == track.id {
            selectedTrack = nil
        }
    }
    
    // MARK: - 批量移除选中文件
    func removeSelectedTracks() {
        tracks.removeAll { selectedIDs.contains($0.id) }
        selectedIDs = []
        detailTrack = nil
        showDetailPanel = false
    }

    // MARK: - 批量同步选中文件封面
    func syncCoversForSelected() {
        let targets = tracks.filter { selectedIDs.contains($0.id) && $0.coverNotSynced }
        Task {
            isBatchProcessing = true
            batchProgress = 0.0
            batchLog = []
            showBatchPanel = true
            let total = targets.count
            for (index, track) in targets.enumerated() {
                do {
                    try FLACParser.syncCoverToID3(track: track, settings: settings)
                    batchLog.append(BatchLogEntry(fileName: track.fileName, status: .success, message: "封面同步成功"))
                } catch {
                    batchLog.append(BatchLogEntry(fileName: track.fileName, status: .failure, message: error.localizedDescription))
                }
                batchProgress = Double(index + 1) / Double(total)
            }
            isBatchProcessing = false
            batchLog.append(BatchLogEntry(fileName: "", status: .info, message: "完成！共处理 \(total) 个文件"))
        }
    }

    // MARK: - 在 Finder 中显示多个文件
    func revealSelectedInFinder() {
        let urls = tracks.filter { selectedIDs.contains($0.id) }.map { $0.url }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    
    // MARK: - 清空整个列表
    func clearAll() {
        tracks = []
        selectedTrack = nil
        batchLog = []
    }
    
    // MARK: - 单首封面同步到 ID3
    func syncCover(track: FLACTrack) {
        Task {
            do {
                try FLACParser.syncCoverToID3(track: track, settings: settings)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - 当单选时自动同步详情面板内容
    func updateDetailIfNeeded() {
        // 只有单选且详情面板已打开时才自动切换
        if showDetailPanel && selectedIDs.count == 1,
           let id = selectedIDs.first,
           let track = tracks.first(where: { $0.id == id }) {
            detailTrack = track
        }
    }
    
    // MARK: - 批量同步封面到 ID3
    // 对当前筛选列表中所有有 FLAC 封面但没有 ID3 封面的文件操作
    func batchSyncCovers() {
        // 只处理需要同步的文件（有 FLAC 封面但 ID3 没有）
        let targets = filteredTracks.filter { $0.coverNotSynced }
        guard !targets.isEmpty else {
            showError("当前列表中没有需要同步的文件")
            return
        }
        
        Task {
            isBatchProcessing = true
            batchProgress = 0.0
            batchLog = []
            showBatchPanel = true
            
            let total = targets.count
            
            for (index, track) in targets.enumerated() {
                do {
                    try FLACParser.syncCoverToID3(track: track, settings: settings)
                    batchLog.append(BatchLogEntry(
                        fileName: track.fileName,
                        status: .success,
                        message: "封面同步成功"
                    ))
                } catch {
                    batchLog.append(BatchLogEntry(
                        fileName: track.fileName,
                        status: .failure,
                        message: error.localizedDescription
                    ))
                }
                // 更新进度
                batchProgress = Double(index + 1) / Double(total)
            }
            
            isBatchProcessing = false
            batchLog.append(BatchLogEntry(
                fileName: "",
                status: .info,
                message: "完成！共处理 \(total) 个文件"
            ))
        }
    }
    
    // MARK: - 保存单首文件的元数据编辑
    func saveMetadata(track: FLACTrack) {
        Task {
            do {
                try FLACParser.saveVorbisComment(track: track)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - 切换排序方式
    // 点击同一列则切换升降序，点击不同列则默认升序
    func toggleSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
    }
    
    // MARK: - 显示错误提示
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - 排序字段枚举
enum SortKey: String {
    case title  = "标题"
    case artist = "艺术家"
    case album  = "专辑"
    case year   = "年份"
    case size   = "大小"
}

// MARK: - 批量操作日志条目
struct BatchLogEntry: Identifiable {
    let id = UUID()
    let fileName: String    // 文件名
    let status: BatchStatus // 状态
    let message: String     // 说明信息
}

// MARK: - 批量操作状态枚举
enum BatchStatus {
    case success  // 成功
    case failure  // 失败
    case skipped  // 跳过
    case info     // 普通信息
    
    /// 对应的显示颜色名称
    var colorName: String {
        switch self {
        case .success: return "green"
        case .failure: return "red"
        case .skipped: return "gray"
        case .info:    return "blue"
        }
    }
    
    /// 对应的图标
    var icon: String {
        switch self {
        case .success: return "✅"
        case .failure: return "❌"
        case .skipped: return "－"
        case .info:    return "ℹ️"
        }
    }
}
