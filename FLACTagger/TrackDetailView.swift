import SwiftUI
import UniformTypeIdentifiers
// ============================================================
// TrackDetailView.swift
// 右侧详情面板：选中文件后显示的三个 Tab
// Tab1：元数据编辑  Tab2：封面管理  Tab3：歌词编辑
// ============================================================

struct TrackDetailView: View {
    @ObservedObject var vm: LibraryViewModel
    @ObservedObject var track: FLACTrack
    
    // 当前选中的 Tab
    @State private var selectedTab: DetailTab = .metadata
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Tab 切换栏 ──
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases) { tab in
                    TabButton(
                        title: tab.title,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
                .padding(.top, 8)
            
            // ── Tab 内容区 ──
            // 用 GeometryReader 固定宽度，防止动画过程中滚动条闪烁
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        switch selectedTab {
                        case .metadata:
                            MetadataTabView(vm: vm, track: track)
                        case .cover:
                            CoverTabView(vm: vm, track: track)
                        case .lyrics:
                            LyricsTabView(vm: vm, track: track)
                        }
                    }
                    // 固定内容宽度等于面板宽度，防止横向滚动条出现
                    .frame(width: geometry.size.width)
                }
                // 动画期间隐藏滚动条
                .scrollIndicators(.never)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// ============================================================
// DetailTab 枚举：三个 Tab 的定义
// ============================================================

enum DetailTab: String, CaseIterable, Identifiable {
    case metadata = "元数据"
    case cover    = "封面"
    case lyrics   = "歌词"
    
    var id: String { rawValue }
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .metadata: return "tag"
        case .cover:    return "photo"
        case .lyrics:   return "text.alignleft"
        }
    }
}

// ============================================================
// TabButton：自定义 Tab 切换按钮样式
// ============================================================

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MetadataTabView
// Tab1：元数据编辑
// 分左右两列：左列是 FLAC Vorbis Comment，右列是 ID3 标签
// ============================================================

struct MetadataTabView: View {
    @ObservedObject var vm: LibraryViewModel
    @ObservedObject var track: FLACTrack
    
    // 记录是否有未保存的修改
    @State private var hasChanges = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // ── FLAC 元数据编辑区 ──
            SectionHeader(title: "FLAC 元数据（Vorbis Comment）",
                         subtitle: "这是 FLAC 文件原生的标签格式")
            
            // 字段表单
            VStack(spacing: 10) {
                MetadataField(label: "标题", value: $track.title,
                             onChange: { hasChanges = true })
                MetadataField(label: "艺术家", value: $track.artist,
                             onChange: { hasChanges = true })
                MetadataField(label: "专辑", value: $track.album,
                             onChange: { hasChanges = true })
                MetadataField(label: "年份", value: $track.year,
                             onChange: { hasChanges = true })
                MetadataField(label: "曲目编号", value: $track.trackNumber,
                             onChange: { hasChanges = true })
                MetadataField(label: "流派", value: $track.genre,
                             onChange: { hasChanges = true })
                MetadataField(label: "评论", value: $track.comment,
                             onChange: { hasChanges = true })
            }
            
            // 保存按钮
            if hasChanges {
                HStack {
                    Spacer()
                    Button("保存修改") {
                        vm.saveMetadata(track: track)
                        hasChanges = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
            
            // ── ID3 标签显示区 ──
            SectionHeader(
                title: "ID3 标签",
                subtitle: track.hasID3Tag ? "文件已包含 ID3 标签" : "文件暂无 ID3 标签"
            )
            
            if track.hasID3Tag {
                // 以只读方式显示 ID3 字段（对比参考用）
                VStack(spacing: 8) {
                    ID3Field(label: "标题",   value: track.id3Title)
                    ID3Field(label: "艺术家", value: track.id3Artist)
                    ID3Field(label: "专辑",   value: track.id3Album)
                    ID3Field(label: "年份",   value: track.id3Year)
                }
                
                // 封面同步按钮
                if track.coverNotSynced {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("FLAC 有封面但 ID3 中没有")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("立即同步封面") {
                            vm.syncCover(track: track)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(8)
                }
            } else {
                // 没有 ID3 标签时的提示
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("点击「封面」标签页可将 FLAC 封面同步写入 ID3 标签")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
            
            Spacer(minLength: 20)
        }
        .padding(16)
    }
}

// ============================================================
// CoverTabView
// Tab2：封面管理
// 显示 FLAC 封面和 ID3 封面，支持导入、粘贴、同步、导出
// ============================================================

struct CoverTabView: View {
    @ObservedObject var vm: LibraryViewModel
    @ObservedObject var track: FLACTrack
    
    // 错误/成功提示
    @State private var message: String = ""
    @State private var messageIsError: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // ── FLAC 封面区 ──
            SectionHeader(title: "FLAC 封面（PICTURE block）",
                         subtitle: "存储在 FLAC 元数据块中的原生封面")
            
            CoverImageView(
                data: track.flacCoverData,
                label: "FLAC 封面"
            )
            
            // FLAC 封面操作按钮组
            HStack(spacing: 8) {
                // 从文件导入
                Button {
                    importCoverFromFile()
                } label: {
                    Label("从文件导入", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // 从粘贴板粘贴（⌘V）
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("粘贴图片", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // 从同目录文件自动查找
                Button {
                    findCoverFromDirectory()
                } label: {
                    Label("从目录查找", systemImage: "folder.badge.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                // 导出封面到本地
                if track.flacCoverData != nil {
                    Button {
                        exportFLACCover()
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            // ── ID3 封面区 ──
            SectionHeader(
                title: "ID3 封面（APIC 帧）",
                subtitle: "macOS Finder 读取的封面来源"
            )
            
            CoverImageView(
                data: track.id3CoverData,
                label: "ID3 封面"
            )
            
            // 核心操作：将 FLAC 封面同步到 ID3
            Button {
                syncCoverToID3()
            } label: {
                Label(
                    track.hasID3Tag ? "重新同步 FLAC 封面 → ID3" : "将 FLAC 封面写入 ID3 标签",
                    systemImage: "arrow.down.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(track.flacCoverData == nil)
            .frame(maxWidth: .infinity)
            
            // 操作结果提示
            if !message.isEmpty {
                HStack {
                    Image(systemName: messageIsError
                          ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(messageIsError ? .red : .green)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(messageIsError ? .red : .green)
                }
                .padding(8)
                .background((messageIsError ? Color.red : Color.green).opacity(0.08))
                .cornerRadius(6)
            }
            
            Spacer(minLength: 20)
        }
        .padding(16)
    }
    
    // MARK: - 从本地文件导入封面
    private func importCoverFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.jpeg,
            UTType.png,
            UTType(filenameExtension: "webp") ?? UTType.image
        ]
        panel.title = "选择封面图片"
        panel.prompt = "导入"
        
        if panel.runModal() == .OK, let url = panel.url {
            guard var data = try? Data(contentsOf: url) else {
                showMessage("读取图片失败", isError: true)
                return
            }
            // 检查是否需要缩放
            if let image = NSImage(data: data) {
                let maxSize = AppSettings.shared.maxCoverSize
                let resized = ImageProcessor.resizeIfNeeded(image, maxSize: maxSize)
                // 转换为 JPEG 格式写入
                if let jpegData = ImageProcessor.toJPEGData(resized, maxSize: maxSize) {
                    data = jpegData
                }
            }
            track.flacCoverData = data
            track.flacCoverMime = "image/jpeg"
            showMessage("封面导入成功，记得点击同步写入 ID3", isError: false)
        }
    }
    
    // MARK: - 从粘贴板粘贴封面图片
    private func pasteFromClipboard() {
        guard let image = ImageProcessor.imageFromPasteboard() else {
            showMessage("粘贴板中没有图片", isError: true)
            return
        }
        let maxSize = AppSettings.shared.maxCoverSize
        guard let jpegData = ImageProcessor.toJPEGData(image, maxSize: maxSize) else {
            showMessage("图片转换失败", isError: true)
            return
        }
        track.flacCoverData = jpegData
        track.flacCoverMime = "image/jpeg"
        
        // 显示缩放提示
        let originalSize = max(image.size.width, image.size.height)
        if Int(originalSize) > maxSize {
            showMessage("图片已自动缩放至 \(maxSize)px 并导入", isError: false)
        } else {
            showMessage("图片已从粘贴板导入", isError: false)
        }
    }
    
    // MARK: - 从同目录自动查找封面
    private func findCoverFromDirectory() {
        guard let data = ImageProcessor.findCoverInDirectory(for: track.url) else {
            showMessage("同目录下未找到封面图片文件", isError: true)
            return
        }
        track.flacCoverData = data
        track.flacCoverMime = ImageProcessor.mimeType(for: data)
        showMessage("已从目录找到封面图片", isError: false)
    }
    
    // MARK: - 同步 FLAC 封面到 ID3
    private func syncCoverToID3() {
        guard track.flacCoverData != nil else {
            showMessage("没有 FLAC 封面可同步", isError: true)
            return
        }
        do {
            try FLACParser.syncCoverToID3(track: track, settings: AppSettings.shared)
            showMessage("✓ 封面已成功写入 ID3 标签", isError: false)
        } catch {
            showMessage(error.localizedDescription, isError: true)
        }
    }
    
    // MARK: - 导出 FLAC 封面到本地文件
    private func exportFLACCover() {
        guard let data = track.flacCoverData else { return }
        
        let format = ImageProcessor.detectFormat(data)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(track.displayTitle) - cover.\(format.fileExtension)"
        panel.title = "导出封面图片"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                showMessage("封面已导出", isError: false)
            } catch {
                showMessage("导出失败：\(error.localizedDescription)", isError: true)
            }
        }
    }
    
    // MARK: - 显示操作结果提示
    private func showMessage(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
        // 3 秒后自动清除提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            message = ""
        }
    }
}

// ============================================================
// LyricsTabView
// Tab3：歌词编辑
// 支持纯文本和 LRC 格式，可从同目录 .lrc 文件导入
// ============================================================

struct LyricsTabView: View {
    @ObservedObject var vm: LibraryViewModel
    @ObservedObject var track: FLACTrack
    
    // 检测当前歌词格式
    private var lyricsFormat: LyricsFormat {
        LyricsFormat.detect(track.lyrics)
    }
    
    @State private var hasChanges = false
    @State private var message = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // ── 标题和格式标签 ──
            HStack {
                SectionHeader(
                    title: "歌词内容",
                    subtitle: track.lyrics.isEmpty ? "暂无歌词" : "共 \(track.lyrics.components(separatedBy: "\n").count) 行"
                )
                Spacer()
                // 显示当前歌词格式
                if !track.lyrics.isEmpty {
                    Text(lyricsFormat == .lrc ? "LRC 格式" : "纯文本")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }
            }
            
            // ── 歌词编辑框 ──
            TextEditor(text: $track.lyrics)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 200)
                .border(Color.secondary.opacity(0.2), width: 1)
                .onChange(of: track.lyrics) { _, _ in
                    hasChanges = true
                }
            
            // LRC 格式说明
            if lyricsFormat == .lrc {
                Text("检测到 LRC 时间轴格式，格式如：[00:12.34] 歌词内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // ── 操作按钮 ──
            HStack(spacing: 8) {
                // 从同目录 .lrc 文件导入
                Button {
                    importFromLRC()
                } label: {
                    Label("从 .lrc 导入", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // 清空歌词
                if !track.lyrics.isEmpty {
                    Button {
                        track.lyrics = ""
                        hasChanges = true
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                // 保存到 FLAC 文件
                if hasChanges {
                    Button("保存歌词") {
                        vm.saveMetadata(track: track)
                        hasChanges = false
                        message = "歌词已保存"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            message = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // 操作提示
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer(minLength: 20)
        }
        .padding(16)
    }
    
    // MARK: - 从同目录 .lrc 文件导入歌词
    private func importFromLRC() {
        // 先尝试自动查找同名 .lrc 文件
        let lrcURL = track.url.deletingPathExtension().appendingPathExtension("lrc")
        
        if FileManager.default.fileExists(atPath: lrcURL.path) {
            // 找到同名 .lrc，自动导入
            loadLRC(from: lrcURL)
        } else {
            // 没找到，弹出文件选择框
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.init(filenameExtension: "lrc") ?? .plainText]
            panel.title = "选择 LRC 歌词文件"
            panel.directoryURL = track.url.deletingLastPathComponent()
            
            if panel.runModal() == .OK, let url = panel.url {
                loadLRC(from: url)
            }
        }
    }
    
    // MARK: - 读取 LRC 文件内容（自动处理编码）
    private func loadLRC(from url: URL) {
        // 优先尝试 UTF-8，其次尝试 GBK（兼容部分旧版歌词文件）
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            track.lyrics = content
            hasChanges = true
            message = "已从 \(url.lastPathComponent) 导入歌词"
        } else if let content = try? String(contentsOf: url, encoding: .init(rawValue: 0x80000632)) {
            // 0x80000632 = kCFStringEncodingGB_18030_2000，兼容 GBK/GB2312
            track.lyrics = content
            hasChanges = true
            message = "已导入歌词（GBK 编码已转换为 UTF-8）"
        } else {
            message = "无法读取歌词文件，请确认编码格式"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            message = ""
        }
    }
}

// ============================================================
// CoverImageView
// 通用封面图片展示组件
// ============================================================

struct CoverImageView: View {
    let data: Data?
    let label: String
    
    var body: some View {
        Group {
            if let data = data, let image = ImageProcessor.toNSImage(data) {
                // 有封面：显示图片和尺寸信息
                VStack(spacing: 6) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                    
                    HStack {
                        Text(ImageProcessor.sizeDescription(data))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(ImageProcessor.mimeType(for: data)
                            .replacingOccurrences(of: "image/", with: "")
                            .uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(
                            fromByteCount: Int64(data.count),
                            countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // 无封面：占位视图
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.slash")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("暂无\(label)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

// ============================================================
// MetadataField：可编辑的元数据字段行
// ============================================================

struct MetadataField: View {
    let label: String
    @Binding var value: String
    let onChange: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 字段名标签（固定宽度，右对齐）
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
                .padding(.trailing, 10)
            
            // 可编辑文本框
            TextField(label, text: $value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onChange(of: value) { _, _ in onChange() }
        }
    }
}

// ============================================================
// ID3Field：只读的 ID3 字段展示行
// ============================================================

struct ID3Field: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
                .padding(.trailing, 10)
            
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 13))
                .foregroundColor(value.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(6)
        }
    }
}

// ============================================================
// SectionHeader：区域标题组件
// ============================================================

struct SectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
