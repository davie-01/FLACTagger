import SwiftUI

// ============================================================
// FLACTaggerApp.swift
// App 入口：配置窗口样式和菜单
// ============================================================

@main
struct FLACTaggerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 设置窗口标题和最小尺寸
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // ── 文件菜单 ──
            CommandGroup(replacing: .newItem) {
                Button("导入文件...") {
                    // 通过通知触发导入（跨视图通信）
                    NotificationCenter.default.post(
                        name: .importFiles, object: nil
                    )
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

// MARK: - 自定义通知名称
extension Notification.Name {
    /// 触发文件导入的通知
    static let importFiles = Notification.Name("importFiles")
}
