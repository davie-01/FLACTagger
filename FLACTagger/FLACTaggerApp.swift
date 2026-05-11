import SwiftUI

// ============================================================
// FLACTaggerApp.swift
// App 入口：配置窗口样式和菜单
// ============================================================
// 让视图接受第一次鼠标点击（不需要先激活窗口）
// 通过 NSViewRepresentable 桥接 AppKit 的 acceptsFirstMouse
struct FirstMouseView: NSViewRepresentable {
    func makeNSView(context: Context) -> FirstMouseNSView {
        return FirstMouseNSView()
    }
    func updateNSView(_ nsView: FirstMouseNSView, context: Context) {}
}

class FirstMouseNSView: NSView {
    // 返回 true 让视图直接响应第一次点击，无需先激活窗口
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
// 自定义 AppDelegate 设置窗口行为
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 遍历所有窗口，设置接受第一次鼠标点击
        for window in NSApplication.shared.windows {
            window.acceptsMouseMovedEvents = true
        }
    }
    
    // 点击 Dock 图标时激活 App
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }
}

@main
struct FLACTaggerApp: App {
    // 注册 AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 让每个视图都接受第一次点击
                .onAppear {
                    NSApplication.shared.windows.forEach {
                        $0.acceptsMouseMovedEvents = true
                        $0.isMovableByWindowBackground = false
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入文件...") {
                    NotificationCenter.default.post(name: .importFiles, object: nil)
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
