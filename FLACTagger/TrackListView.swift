import SwiftUI
import UniformTypeIdentifiers

// ============================================================
// TrackListView.swift
// 文件列表：支持整行悬停高亮、多选、双击详情、右键菜单
// ============================================================

struct TrackListView: View {
    @ObservedObject var vm: LibraryViewModel

    var body: some View {
        Table(vm.filteredTracks, selection: $vm.selectedIDs) {
            // ── 列1：状态图标 ──
            TableColumn("") { track in
                StatusIconsView(track: track)
            }
            .width(60)

            // ── 列2：标题 ──
            TableColumn("歌曲名") { track in
                HStack(spacing: 8) {
                    CoverThumbnailView(track: track)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayTitle)
                            .lineLimit(1)
                            .font(.system(size: 13))
                        Text(track.fileName)
                            .lineLimit(1)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                // 双击显示详情面板
                .onTapGesture(count: 2) {
                    vm.detailTrack = track
                    vm.showDetailPanel = true
                }
            }
            .width(min: 180, ideal: 240)

            // ── 列3：艺术家 ──
            TableColumn("艺术家") { track in
                Text(track.artist)
                    .lineLimit(1)
                    .font(.system(size: 13))
                    .foregroundColor(track.missingArtist ? .secondary : .primary)
            }
            .width(min: 100, ideal: 140)

            // ── 列4：专辑 ──
            TableColumn("专辑") { track in
                Text(track.album.isEmpty ? "—" : track.album)
                    .lineLimit(1)
                    .font(.system(size: 13))
                    .foregroundColor(track.album.isEmpty ? .secondary : .primary)
            }
            .width(min: 100, ideal: 140)

            // ── 列5：年份 ──
            TableColumn("年份") { track in
                Text(track.year.isEmpty ? "—" : track.year)
                    .font(.system(size: 13))
                    .foregroundColor(track.year.isEmpty ? .secondary : .primary)
            }
            .width(50)

            // ── 列6：大小 ──
            TableColumn("大小") { track in
                Text(track.fileSizeString)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .width(70)
        }
        // 整行右键菜单（支持多选）
        .contextMenu(forSelectionType: FLACTrack.ID.self) { ids in
            let isSingle = ids.count == 1
            let tracks = vm.tracks.filter { ids.contains($0.id) }

            // 详情（仅单选时可用）
            Button {
                if let track = tracks.first {
                    vm.detailTrack = track
                    vm.showDetailPanel = true
                }
            } label: {
                Label("详情", systemImage: "info.circle")
            }
            .disabled(!isSingle)

            Divider()

            // 在 Finder 中显示
            Button {
                NSWorkspace.shared.activateFileViewerSelecting(tracks.map { $0.url })
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }

            // 同步封面到 ID3
            Button {
                if isSingle, let track = tracks.first {
                    vm.syncCover(track: track)
                } else {
                    vm.selectedIDs = ids
                    vm.syncCoversForSelected()
                }
            } label: {
                Label("同步封面到 ID3", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(tracks.allSatisfy { $0.flacCoverData == nil })

            Divider()

            // 从列表移除
            Button(role: .destructive) {
                vm.selectedIDs = ids
                vm.removeSelectedTracks()
            } label: {
                Label("从列表移除", systemImage: "minus.circle")
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
        // 监听选中变化，自动更新详情面板
        .onChange(of: vm.selectedIDs) { _, newIDs in
            vm.updateDetailIfNeeded()
            // 点击空白处（selectedIDs 变为空）时关闭详情面板
            if newIDs.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.showDetailPanel = false
                }
            }
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
