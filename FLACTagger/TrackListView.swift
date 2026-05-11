import SwiftUI
import UniformTypeIdentifiers

// ============================================================
// TrackListView.swift
// 完全自定义选中逻辑，解决 List selection 失效问题
// ============================================================

struct TrackListView: View {
    @ObservedObject var vm: LibraryViewModel
    @State private var hoveredID: FLACTrack.ID? = nil
    var body: some View {
        VStack(spacing: 0) {
            // 固定表头
            TrackListHeader()
            Divider()

            // 列表主体
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.filteredTracks) { track in
                        TrackRowView(track: track, vm: vm)
                            .background(
                                Group {
                                    if vm.selectedIDs.contains(track.id) {
                                        Color.accentColor.opacity(0.25)
                                    } else if hoveredID == track.id {
                                        Color.primary.opacity(0.06)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleSingleTap(track: track)
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    handleDoubleTap(track: track)
                                }
                            )
                            .contextMenu {
                                TrackRowContextMenu(vm: vm, track: track)
                            }
                            .onHover { isHovered in
                                // 直接在闭包里修改 hoveredID，可以访问到
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    hoveredID = isHovered ? track.id : nil
                                }
                            }

                        Divider()
                            .opacity(0.5)
                    }
                }
            }
            // Command+A 全选
            .onKeyPress(keys: [KeyEquivalent("a")], phases: .down) { press in
                if press.modifiers.contains(.command) {
                    vm.selectedIDs = Set(vm.filteredTracks.map { $0.id })
                    return .handled
                }
                return .ignored
            }
        }
    }


    // MARK: - 单击选中逻辑
    private func handleSingleTap(track: FLACTrack) {
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []

        if modifiers.contains(.command) {
            // Command+点击：切换该项的选中状态
            if vm.selectedIDs.contains(track.id) {
                vm.selectedIDs.remove(track.id)
            } else {
                vm.selectedIDs.insert(track.id)
            }
        } else if modifiers.contains(.shift), let lastID = vm.selectedIDs.first {
            // Shift+点击：范围选择
            let tracks = vm.filteredTracks
            if let lastIndex = tracks.firstIndex(where: { $0.id == lastID }),
               let currentIndex = tracks.firstIndex(where: { $0.id == track.id }) {
                let range = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
                vm.selectedIDs = Set(tracks[range].map { $0.id })
            }
        } else {
            // 普通单击：只选中这一项
            vm.selectedIDs = [track.id]
            // 单选时同步更新详情面板内容
            if vm.showDetailPanel {
                vm.detailTrack = track
            }
        }

        // 选中变化时检查是否需要关闭详情
        if vm.selectedIDs.isEmpty {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                vm.showDetailPanel = false
            }
        }
    }

    // MARK: - 双击打开详情
    private func handleDoubleTap(track: FLACTrack) {
        vm.selectedIDs = [track.id]
        vm.detailTrack = track
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            vm.showDetailPanel = true
        }
    }
}

// ============================================================
// TrackListHeader - 固定表头
// ============================================================
struct TrackListHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 70)
            Text("歌曲名")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("艺术家")
                .frame(width: 140, alignment: .leading)
            Text("专辑")
                .frame(width: 160, alignment: .leading)
            Text("年份")
                .frame(width: 50, alignment: .leading)
            Text("大小")
                .frame(width: 70, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// ============================================================
// TrackRowView - 每行内容
// ============================================================
struct TrackRowView: View {
    @ObservedObject var track: FLACTrack
    @ObservedObject var vm: LibraryViewModel
    // 当前鼠标悬停的行 ID
    @State private var hoveredID: FLACTrack.ID? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            StatusIconsView(track: track)
                .frame(width: 70, alignment: .leading)

            HStack(spacing: 8) {
                CoverThumbnailView(track: track)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(track.fileName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(track.artist.isEmpty ? "—" : track.artist)
                .font(.system(size: 12))
                .foregroundColor(track.missingArtist ? .secondary : .primary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(track.album.isEmpty ? "—" : track.album)
                .font(.system(size: 12))
                .foregroundColor(track.album.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)

            Text(track.year.isEmpty ? "—" : track.year)
                .font(.system(size: 12))
                .foregroundColor(track.year.isEmpty ? .secondary : .primary)
                .frame(width: 50, alignment: .leading)

            Text(track.fileSizeString)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

// ============================================================
// TrackRowContextMenu - 右键菜单
// ============================================================
struct TrackRowContextMenu: View {
    @ObservedObject var vm: LibraryViewModel
    let track: FLACTrack

    var body: some View {
        let selectedTracks = vm.tracks.filter { vm.selectedIDs.contains($0.id) }
        let isMultiSelect = vm.selectedIDs.count > 1

        Button {
            vm.detailTrack = track
            vm.showDetailPanel = true
        } label: {
            Label("详情", systemImage: "info.circle")
        }
        .disabled(isMultiSelect)

        Divider()

        Button {
            let urls = isMultiSelect
                ? selectedTracks.map { $0.url }
                : [track.url]
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        } label: {
            Label("在 Finder 中显示", systemImage: "folder")
        }

        Button {
            if isMultiSelect {
                vm.syncCoversForSelected()
            } else {
                vm.syncCover(track: track)
            }
        } label: {
            Label("同步封面到 ID3", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(isMultiSelect
            ? selectedTracks.allSatisfy { $0.flacCoverData == nil }
            : track.flacCoverData == nil)

        Divider()

        Button(role: .destructive) {
            if isMultiSelect {
                vm.removeSelectedTracks()
            } else {
                vm.removeTrack(track)
            }
        } label: {
            Label("从列表移除", systemImage: "minus.circle")
        }
    }
}

// ============================================================
// StatusIconsView - 状态图标
// ============================================================
struct StatusIconsView: View {
    @ObservedObject var track: FLACTrack

    var body: some View {
        HStack(spacing: 3) {
            if track.flacCoverData != nil {
                Image(systemName: "photo.fill")
                    .font(.system(size: 9))
                    .foregroundColor(track.coverNotSynced ? .orange : .green)
                    .help(track.coverNotSynced ? "有封面但 ID3 未同步" : "封面已同步")
            } else {
                Image(systemName: "photo.slash")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .help("无封面")
            }
            Image(systemName: track.missingLyrics ? "text.bubble" : "text.bubble.fill")
                .font(.system(size: 9))
                .foregroundColor(track.missingLyrics ? .secondary : .green)
                .help(track.missingLyrics ? "无歌词" : "有歌词")
            if track.hasID3Tag {
                Text("ID3")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.blue)
                    .help("已有 ID3 标签")
            }
        }
    }
}

// ============================================================
// CoverThumbnailView - 封面缩略图
// ============================================================
struct CoverThumbnailView: View {
    @ObservedObject var track: FLACTrack

    var body: some View {
        Group {
            if let data = track.flacCoverData ?? track.id3CoverData,
               let image = ImageProcessor.toNSImage(data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    )
            }
        }
    }
}
