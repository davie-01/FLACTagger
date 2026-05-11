import SwiftUI

// ============================================================
// ContentView.swift
// App 根视图：直接使用 MainView 作为主界面
// ============================================================

struct ContentView: View {
    var body: some View {
        MainView()
            // 叠加一个透明的 FirstMouseView，让整个窗口接受第一次点击
            .background(FirstMouseView())
    }
}
