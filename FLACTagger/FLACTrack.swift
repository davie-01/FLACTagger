import Foundation
import AppKit
import Combine

// ============================================================
// FLACTrack.swift
// 核心数据模型：代表一个 FLAC 音乐文件的所有信息
// 包括 Vorbis Comment 元数据、ID3 标签、封面、歌词等
// ============================================================

// MARK: - 主数据模型
class FLACTrack: ObservableObject, Identifiable, Hashable {
    let id = UUID()
    
    /// 文件在磁盘上的路径
    let url: URL
    
    /// 文件大小（字节）
    let fileSize: Int64
    
    // MARK: FLAC Vorbis Comment 元数据字段
    @Published var title: String = ""        // 歌曲标题
    @Published var artist: String = ""       // 艺术家
    @Published var album: String = ""        // 专辑名
    @Published var year: String = ""         // 年份
    @Published var trackNumber: String = ""  // 曲目编号
    @Published var genre: String = ""        // 流派
    @Published var comment: String = ""      // 评论
    @Published var lyrics: String = ""       // 歌词（纯文本或 LRC 格式）
    
    // MARK: 封面数据
    @Published var flacCoverData: Data? = nil   // FLAC PICTURE block 中的封面原始数据
    @Published var flacCoverMime: String = ""    // 封面的 MIME 类型（image/jpeg 等）
    @Published var id3CoverData: Data? = nil     // ID3 APIC 帧中的封面原始数据
    
    // MARK: ID3 标签字段（从文件头部 ID3 块读取）
    @Published var id3Title: String = ""
    @Published var id3Artist: String = ""
    @Published var id3Album: String = ""
    @Published var id3Year: String = ""
    
    // MARK: 状态标志
    @Published var hasID3Tag: Bool = false           // 是否有 ID3 标签
    @Published var isLoaded: Bool = false            // 是否已完成解析
    
    /// 是否缺少封面（FLAC 和 ID3 都没有）
    var missingCover: Bool { flacCoverData == nil && id3CoverData == nil }
    
    /// 是否缺少歌词
    var missingLyrics: Bool { lyrics.trimmingCharacters(in: .whitespaces).isEmpty }
    
    /// 是否缺少艺术家
    var missingArtist: Bool { artist.trimmingCharacters(in: .whitespaces).isEmpty }
    
    /// ID3 封面是否与 FLAC 封面不同步（FLAC 有封面但 ID3 没有）
    var coverNotSynced: Bool { flacCoverData != nil && id3CoverData == nil }
    
    /// 文件名（不含路径）
    var fileName: String { url.lastPathComponent }
    
    /// 显示用的标题（优先用元数据标题，没有则用文件名）
    var displayTitle: String { title.isEmpty ? url.deletingPathExtension().lastPathComponent : title }
    
    /// 文件大小的可读字符串（如 "4.2 MB"）
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    // Hashable 协议实现：用 id 作为哈希依据
    static func == (lhs: FLACTrack, rhs: FLACTrack) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: 初始化
    init(url: URL) {
        self.url = url
        // 读取文件大小
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.fileSize = attrs?[.size] as? Int64 ?? 0
    }
}

// MARK: - 侧边栏筛选分类
enum SidebarFilter: String, CaseIterable, Identifiable {
    case all        = "所有文件"
    case noCover    = "缺少封面"
    case noLyrics   = "缺少歌词"
    case noArtist   = "缺少艺术家"
    case notSynced  = "ID3 未同步"
    
    var id: String { rawValue }
    
    /// 对应的 SF Symbol 图标名称
    var icon: String {
        switch self {
        case .all:       return "music.note.list"
        case .noCover:   return "photo.slash"
        case .noLyrics:  return "text.bubble.slash" // 修改为可用图标
        case .noArtist:  return "person.slash"      // 修改为可用图标
        case .notSynced: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - 歌词格式检测
enum LyricsFormat {
    case plain  // 纯文本歌词
    case lrc    // LRC 时间轴格式（如 [00:12.34] 歌词内容）
    
    /// 自动检测歌词格式
    static func detect(_ text: String) -> LyricsFormat {
        // LRC 格式特征：包含 [分钟:秒.毫秒] 格式的时间标签
        let lrcPattern = #"\[\d{2}:\d{2}[.:]\d{2}\]"#
        if let _ = text.range(of: lrcPattern, options: .regularExpression) {
            return .lrc
        }
        return .plain
    }
}

// MARK: - 应用设置
class AppSettings: ObservableObject {
    /// 是否在修改前自动备份文件（默认关闭）
    @Published var enableBackup: Bool = false
    
    /// 封面图片最大边长（超过此尺寸自动缩放，默认 1000px）
    @Published var maxCoverSize: Int = 1000
    
    /// 扫描文件夹时是否递归进入子目录（默认开启）
    @Published var scanSubdirectories: Bool = true
    
    /// 备份目录（nil 表示使用原文件同目录）
    @Published var backupDirectory: URL? = nil

    /// 备份目录的可读字符串
    var backupDirectoryDisplay: String {
        backupDirectory?.path ?? "与原文件相同目录"
    }
    
    // 单例，全局共享
    static let shared = AppSettings()
    private init() {}
}
