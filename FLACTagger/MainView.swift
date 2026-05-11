import SwiftUI
import UniformTypeIdentifiers

// ============================================================
// MainView.swift
// 主界面：固定宽度侧边栏 + 主内容区布局
// 侧边栏宽度固定不可拖动，避免布局错乱
// ============================================================

struct MainView: View {

    // MARK: - 视图模型
    @StateObject private var vm = LibraryViewModel()

    // MARK: - 拖拽状态
    @State private var isDragging = false

    // MARK: - 侧边栏显示控制
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {

            // ── 左侧侧边栏（固定宽度，toggleable）──
            if showSidebar {
                SidebarView(vm: vm)
                    .frame(width: 180)
                    .transition(.move(edge: .leading))

                Divider()
            }

            // ── 右侧主内容区 ──
            VStack(spacing: 0) {

                // 顶部工具栏
                ToolbarAreaView(vm: vm, showSidebar: $showSidebar)

                Divider()

                if vm.tracks.isEmpty {
                    // 空状态引导
                    EmptyStateView(vm: vm, isDragging: $isDragging)
                } else {
                    // 文件列表 + 详情面板
                    HStack(spacing: 0) {

                        // 左：文件列表
                        TrackListView(vm: vm)
                            .frame(minWidth: 400)

                        // 右：详情面板（有选中文件且已触发时显示）
                        if vm.showDetailPanel, let track = vm.detailTrack {
                            HStack(spacing: 0) {
                                // 折叠箭头控制条
                                Button {
                                    withAnimation(.spring(response: 0.38,
                                                         dampingFraction: 0.88)) {
                                        vm.showDetailPanel = false
                                    }
                                } label: {
                                    ZStack {
                                        Rectangle()
                                            .fill(Color(NSColor.separatorColor))
                                            .frame(width: 1)
                                        Circle()
                                            .fill(Color(NSColor.controlBackgroundColor))
                                            .frame(width: 20, height: 20)
                                            .shadow(color: .black.opacity(0.15), radius: 3)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .frame(width: 20)
                                .help("收起详情")
                                .onHover { inside in
                                    if inside { NSCursor.pointingHand.push() }
                                    else { NSCursor.pop() }
                                }

                                // 详情内容
                                TrackDetailView(vm: vm, track: track)
                                    .frame(minWidth: 300, maxWidth: 420)
                                    .clipped()
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.spring(response: 0.38, dampingFraction: 0.88),
                               value: vm.showDetailPanel)
                }

                // 批量处理进度面板
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
        // 动画控制侧边栏显示/隐藏
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showSidebar)
        // 错误弹窗
        .alert("出错了", isPresented: $vm.showError) {
            Button("确定") { vm.showError = false }
        } message: {
            Text(vm.errorMessage ?? "未知错误")
        }
        .frame(minWidth: 900, minHeight: 600)
        // 注册系统工具栏按钮（左上角侧边栏开关）
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .focusEffectDisabled()
                .help(showSidebar ? "隐藏侧边栏" : "显示侧边栏")
            }
        }
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
// SidebarView - 左侧侧边栏
// ============================================================
struct SidebarView: View {
    @ObservedObject var vm: LibraryViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("FLACTagger")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // 筛选列表
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SidebarFilter.allCases) { filter in
                        SidebarFilterRow(
                            filter: filter,
                            count: countFor(filter),
                            isSelected: vm.sidebarFilter == filter
                        ) {
                            vm.sidebarFilter = filter
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }

            Spacer()

            Divider()

            // 底部设置按钮
            Button {
                showSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                    Text("设置")
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

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
// SidebarFilterRow - 侧边栏每个筛选项
// ============================================================
struct SidebarFilterRow: View {
    let filter: SidebarFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16)

                Text(filter.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()

                // 数量角标
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.secondary.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// ToolbarAreaView - 顶部工具栏
// ============================================================
struct ToolbarAreaView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var showSidebar: Bool

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

            // 批量同步封面按钮
            if vm.notSyncedCount > 0 {
                Button {
                    vm.batchSyncCovers()
                } label: {
                    Label("全部同步封面", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isBatchProcessing)
            }

            // 导入文件按钮
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
// EmptyStateView - 空状态引导界面
// ============================================================
struct EmptyStateView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var isDragging: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: isDragging ? "arrow.down.circle.fill" : "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(isDragging ? .accentColor : .secondary)
                .animation(.spring(response: 0.3), value: isDragging)

            Text(isDragging ? "松开以导入" : "拖入 FLAC 文件或文件夹")
                .font(.title2)
                .foregroundColor(isDragging ? .primary : .secondary)

            Text("支持单个文件、多个文件或整个文件夹")
                .font(.callout)
                .foregroundColor(.secondary)

            Button("选择文件...") {
                vm.openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDragging ? Color.accentColor : Color.clear, lineWidth: 2)
                .padding(8)
        )
    }
}

// ============================================================
// BatchProgressView - 批量处理进度面板
// ============================================================
struct BatchProgressView: View {
    @ObservedObject var vm: LibraryViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                HStack {
                    Text(vm.isBatchProcessing ? "正在批量处理..." : "处理完成")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation { vm.showBatchPanel = false }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isBatchProcessing)
                }

                if vm.isBatchProcessing {
                    ProgressView(value: vm.batchProgress)
                        .progressViewStyle(.linear)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.batchLog) { entry in
                            HStack(spacing: 6) {
                                Text(entry.status.icon)
                                    .font(.system(size: 11))
                                if !entry.fileName.isEmpty {
                                    Text(entry.fileName)
                                        .font(.system(size: 11, design: .monospaced))
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
// SettingsView - 设置面板
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
            Toggle("修改前自动备份文件（生成 .bak 文件）", isOn: $settings.enableBackup)
            Text("开启后每次修改文件前会生成 .bak 备份")
                .font(.caption)
                .foregroundColor(.secondary)

            // 备份目录选择
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
        .frame(width: 420, height: 320)
    }
}
