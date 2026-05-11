import Foundation
import AppKit
import CoreImage

// ============================================================
// ImageProcessor.swift
// 图片处理器：负责封面图片的缩放、格式转换、粘贴板读取等操作
// ============================================================

class ImageProcessor {
    
    // MARK: - 从粘贴板读取图片
    // 支持直接 ⌘V 粘贴截图或从其他 App 复制的图片
    static func imageFromPasteboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        // 按优先级尝试读取不同格式
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        return image
    }
    
    // MARK: - 将 NSImage 转换为 JPEG Data
    // 超过 maxSize 的图片会先等比缩放再转换
    static func toJPEGData(_ image: NSImage, maxSize: Int = 1000, quality: CGFloat = 0.85) -> Data? {
        // 先缩放到合适尺寸
        let resized = resizeIfNeeded(image, maxSize: maxSize)
        
        guard let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        // 使用 JPEG 格式压缩，quality 范围 0.0-1.0
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
    
    // MARK: - 将 NSImage 转换为 PNG Data
    static func toPNGData(_ image: NSImage, maxSize: Int = 1000) -> Data? {
        let resized = resizeIfNeeded(image, maxSize: maxSize)
        guard let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }
    
    // MARK: - 将任意格式图片数据转换为 PNG Data
    // 主要用于把 WebP 等格式统一转为系统可显示的格式
    static func convertToPNG(_ data: Data, maxSize: Int = 1000) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        return toPNGData(image, maxSize: maxSize)
    }
    
    // MARK: - 将任意图片数据转为可显示的 NSImage
    // 对于 WebP 格式，macOS 原生支持，NSImage 可以直接读取
    static func toNSImage(_ data: Data) -> NSImage? {
        return NSImage(data: data)
    }
    
    // MARK: - 等比缩放图片（超过 maxSize 才缩放）
    // maxSize 是长边最大像素数，短边按比例计算
    static func resizeIfNeeded(_ image: NSImage, maxSize: Int) -> NSImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        // 如果图片尺寸在限制内，直接返回原图
        guard maxDimension > CGFloat(maxSize) else { return image }
        
        // 计算缩放比例
        let scale = CGFloat(maxSize) / maxDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // 创建新的 NSImage 并绘制缩放后的图片
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()
        
        return resized
    }
    
    // MARK: - 从本地文件路径读取图片
    static func imageFromFile(_ url: URL) -> NSImage? {
        return NSImage(contentsOf: url)
    }
    
    // MARK: - 在同目录下寻找封面图片文件
    // 按优先级查找：cover.jpg > folder.jpg > artwork.jpg > 同名图片
    static func findCoverInDirectory(for trackURL: URL) -> Data? {
        let dir = trackURL.deletingLastPathComponent()
        
        // 候选文件名列表，按优先级排列
        let candidates = [
            "cover.jpg", "cover.jpeg", "cover.png",
            "folder.jpg", "folder.jpeg", "folder.png",
            "artwork.jpg", "artwork.jpeg", "artwork.png",
            "front.jpg", "front.jpeg", "front.png"
        ]
        
        // 逐一检查是否存在
        for name in candidates {
            let url = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        
        // 没找到候选文件，尝试同目录下第一个图片文件
        if let files = try? FileManager.default.contentsOfDirectory(at: dir,
            includingPropertiesForKeys: nil) {
            let imageExtensions = ["jpg", "jpeg", "png", "webp"]
            if let imageFile = files.first(where: {
                imageExtensions.contains($0.pathExtension.lowercased())
            }) {
                return try? Data(contentsOf: imageFile)
            }
        }
        
        return nil
    }
    
    // MARK: - 检测图片数据的实际格式
    // 通过文件头（Magic Bytes）判断真实格式，不依赖 MIME 类型字符串
    static func detectFormat(_ data: Data) -> ImageFormat {
        guard data.count >= 4 else { return .unknown }
        
        // JPEG：以 FF D8 FF 开头
        if data.prefix(3) == Data([0xFF, 0xD8, 0xFF]) { return .jpeg }
        
        // PNG：以 89 50 4E 47 开头
        if data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]) { return .png }
        
        // WebP：以 RIFF 开头，第 8-11 字节是 WEBP
        if data.prefix(4) == Data([0x52, 0x49, 0x46, 0x46]) { return .webp }
        
        return .unknown
    }
    
    // MARK: - 获取图片数据对应的 MIME 类型字符串
    static func mimeType(for data: Data) -> String {
        switch detectFormat(data) {
        case .jpeg: return "image/jpeg"
        case .png:  return "image/png"
        case .webp: return "image/webp"
        case .unknown: return "image/jpeg" // 默认当 JPEG 处理
        }
    }
    
    // MARK: - 获取图片尺寸描述字符串（如 "800 × 800"）
    static func sizeDescription(_ data: Data) -> String {
        guard let image = NSImage(data: data) else { return "未知尺寸" }
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        return "\(w) × \(h)"
    }
}

// MARK: - 图片格式枚举
enum ImageFormat {
    case jpeg
    case png
    case webp
    case unknown
    
    /// 对应的文件扩展名
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png:  return "png"
        case .webp: return "webp"
        case .unknown: return "jpg"
        }
    }
    
    /// 对应的 MIME 类型
    var mimeType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .png:  return "image/png"
        case .webp: return "image/webp"
        case .unknown: return "image/jpeg"
        }
    }
}
