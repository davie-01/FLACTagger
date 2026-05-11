import SwiftUI
import UniformTypeIdentifiers

// ============================================================
// MainView.swift
// 主界面：仿 Music.app 的侧边栏 + 主内容区布局
// 包含：侧边栏筛选、文件列表、顶部工具栏、拖拽导入
// ============================================================

struct MainView: View {
    
    // MARK: - 视图模型（整个 App 共享）
    @StateObject private var vm = LibraryViewModel()
    
    // MARK: - 拖拽状态
    @State private var isDragging = false
    
    var body: some View {
        NavigationSplitView {
            // ── 左侧侧边栏 ──
            SidebarView(vm: vm)
        } detail: {
            // ── 右侧主内容区 ──
            VStack(spacing: 0) {
                // 顶部工具栏
                ToolbarAreaView(vm: vm)
                
                Divider()
                
                if vm.tracks.isEmpty {
                    // 空状态：引导用户导入文件
                    EmptyStateView(vm: vm, isDragging: $isDragging)
                } else {
                    // 文件列表 + 底部详情面板
                    HSplitView {
                        // 左：文件列表
                        TrackListView(vm: vm)
                            .frame(minWidth: 400)
                        
                        // 右：详情面板 + 折叠箭头
                        if vm.showDetailPanel, let track = vm.detailTrack {
                            HStack(spacing: 0) {
                                // 左边框折叠箭头
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vm.showDetailPanel = false
                                    }
                                } label: {
                                    VStack {
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .frame(width: 14)
                                    .background(Color(NSColor.separatorColor).opacity(0.3))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("收起详情")
                                .onHover { inside in
                                    if inside { NSCursor.pointingHand.push() }
                                    else { NSCursor.pop() }
                                }
                                
                                TrackDetailView(vm: vm, track: track)
                                    .frame(minWidth: 320, maxWidth: 420)
                            }
                        }
                    }
                }
                
                // 批量操作进度面板（处理时显示）
                if vm.showBatchPanel {
                    BatchProgressView(vm: vm)
                        .transition(.move(edge: .bottom))
                }
            }
            // 接受拖拽文件
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers)
                return true
            }
        }
        // 错误弹窗
        .alert("出错了", isPresented: $vm.showError) {
            Button("确定") { vm.showError = false }
        } message: {
            Text(vm.errorMessage ?? "未知错误")
        }
        // 窗口最小尺寸
        .frame(minWidth: 900, minHeight: 600)
    }
    
    // MARK: - 处理文件拖拽
    private func handleDrop(_ providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            vm.importURLs(urls)
        }
    }
}

// ============================================================
// SidebarView.swift
// 左侧侧边栏：显示筛选分类和数量角标
// ============================================================

struct SidebarView: View {
    @ObservedObject var vm: LibraryViewModel
    @State private var showSettings = false

    var body: some View {
        List(SidebarFilter.allCases, selection: $vm.sidebarFilter) { filter in
            Label {
                HStack {
                    Text(filter.rawValue)
                    Spacer()
                    Text("\(countFor(filter))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            } icon: {
                Image(systemName: filter.icon)
            }
            // 点击时切换筛选
            .tag(filter)
            .onTapGesture {
                vm.sidebarFilter = filter
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FLACTagger")
        // 底部设置按钮
        .safeAreaInset(edge: .bottom) {
            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .background(Color(NSColor.windowBackgroundColor))
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
//获取各分类的数量
    private func countFor(_ filter: SidebarFilter) -> Int {
        switch filter {
        case .all:       return vm.allCount
        case .noCover:   return vm.noCoverCount
        case .noLyrics:  return vm.noLyricsCount
        case .noArtist:  return vm.noArtistCount
        case .notSynced: return vm.notSyncedCount
        }
    }
}

// ============================================================
// ToolbarAreaView
// 顶部工具栏：搜索框、导入按钮、批量操作按钮
// ============================================================

struct ToolbarAreaView: View {
    @ObservedObject var vm: LibraryViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索歌名、歌手...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 300)
            
            Spacer()
            
            // 文件数量统计
            if !vm.tracks.isEmpty {
                Text("\(vm.filteredTracks.count) / \(vm.tracks.count) 首")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // 批量同步按钮
            if vm.notSyncedCount > 0 {
                Button {
                    vm.batchSyncCovers()
                } label: {
                    Label("全部同步封面", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isBatchProcessing)
            }
            
            // 导入按钮
            Button {
                vm.openFilePicker()
            } label: {
                Label("导入文件", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            
            // 清空列表按钮
            if !vm.tracks.isEmpty {
                Button {
                    vm.clearAll()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("清空列表")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// ============================================================
// EmptyStateView
// 空状态引导界面：列表为空时显示，支持拖拽
// ============================================================

struct EmptyStateView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 图标
            Image(systemName: isDragging ? "arrow.down.circle.fill" : "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(isDragging ? .accentColor : .secondary)
                .animation(.spring(response: 0.3), value: isDragging)
            
            // 提示文字
            Text(isDragging ? "松开以导入" : "拖入 FLAC 文件或文件夹")
                .font(.title2)
                .foregroundColor(isDragging ? .primary : .secondary)
            
            Text("支持单个文件、多个文件或整个文件夹")
                .font(.callout)
                .foregroundColor(.secondary)
            
            // 选择按钮
            Button("选择文件...") {
                vm.openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // 拖拽时显示高亮边框
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDragging ? Color.accentColor : Color.clear, lineWidth: 2)
                .padding(8)
        )
    }
}

// ============================================================
// BatchProgressView
// 底部批量处理进度面板
// ============================================================

struct BatchProgressView: View {
    @ObservedObject var vm: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 8) {
                // 标题栏
                HStack {
                    Text(vm.isBatchProcessing ? "正在批量处理..." : "处理完成")
                        .font(.headline)
                    Spacer()
                    // 关闭按钮
                    Button {
                        withAnimation { vm.showBatchPanel = false }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isBatchProcessing) // 处理中不可关闭
                }
                
                // 进度条
                if vm.isBatchProcessing {
                    ProgressView(value: vm.batchProgress)
                        .progressViewStyle(.linear)
                }
                
                // 日志列表
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.batchLog) { entry in
                            HStack(spacing: 6) {
                                Text(entry.status.icon)
                                    .font(.system(size: 11))
                                if !entry.fileName.isEmpty {
                                    Text(entry.fileName)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                                Text(entry.message)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 120)
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// ============================================================
// SettingsButtonView
// 设置按钮（暂时用弹窗实现，后续可扩展为独立设置页）
// ============================================================

struct SettingsButtonView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showSettings = false
    
    var body: some View {
        Button {
            showSettings = true
        } label: {
            Label("设置", systemImage: "gear")
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// ============================================================
// SettingsView
// 设置面板
// ============================================================

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.title2.bold())
            
            Divider()
            
            // 备份开关
            Toggle("修改前自动备份文件", isOn: $settings.enableBackup)
            Text("开启后每次修改文件前会生成 .bak 备份")
                .font(.caption)
                .foregroundColor(.secondary)

            // 备份目录选择（仅备份开启时显示）
            if settings.enableBackup {
                HStack(spacing: 8) {
                    Text("备份目录：")
                        .font(.system(size: 13))
                    Text(settings.backupDirectory?.path ?? "与原文件相同目录")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("选择...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.prompt = "选择"
                        panel.title = "选择备份目录"
                        if panel.runModal() == .OK {
                            settings.backupDirectory = panel.url
                        }
                    }
                    .controlSize(.small)
                    if settings.backupDirectory != nil {
                        Button("重置") {
                            settings.backupDirectory = nil
                        }
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(8)
            }
        
            Text("开启后每次修改文件前会在同目录生成 .bak 备份")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 封面最大尺寸
            HStack {
                Text("封面最大边长：")
                TextField("", value: $settings.maxCoverSize, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("px")
                    .foregroundColor(.secondary)
            }
            Text("粘贴或导入的图片超过此尺寸会自动等比缩放")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 子目录扫描
            Toggle("扫描文件夹时包含子目录", isOn: $settings.scanSubdirectories)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
}
