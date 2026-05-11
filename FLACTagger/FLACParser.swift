import Foundation
import AppKit

// ============================================================
// FLACParser.swift
// FLAC 文件解析器：负责读取和写入 FLAC 文件的所有数据
// 包括：Vorbis Comment 元数据、PICTURE 封面块、ID3 标签
// ============================================================

class FLACParser {
    
    // MARK: - 公开方法：解析整个 FLAC 文件，填充 FLACTrack 对象
    static func parse(track: FLACTrack) {
        guard let data = try? Data(contentsOf: track.url) else { return }
        
        // 先尝试读取 ID3 标签（位于文件最开头）
        var flacStartOffset = 0
        if data.prefix(3) == Data([0x49, 0x44, 0x33]) { // "ID3"
            track.hasID3Tag = true
            flacStartOffset = findFLACStart(in: data)
            parseID3Tag(data: data, track: track)
        }
        
        // 确认 FLAC 标识 "fLaC"
        let flacData = data.dropFirst(flacStartOffset)
        guard flacData.prefix(4) == Data([0x66, 0x4C, 0x61, 0x43]) else { return }
        
        // 解析所有 FLAC Metadata Block
        parseFLACMetadataBlocks(data: Data(flacData), track: track)
        
        track.isLoaded = true
    }
    
    // MARK: - 查找 FLAC 数据在文件中的起始位置（跳过 ID3 标签）
    private static func findFLACStart(in data: Data) -> Int {
        // ID3v2 标签头部共 10 字节
        // 字节 6-9 是 syncsafe 整数表示的标签大小
        guard data.count >= 10 else { return 0 }
        let b6 = Int(data[6]), b7 = Int(data[7]), b8 = Int(data[8]), b9 = Int(data[9])
        let tagSize = (b6 << 21) | (b7 << 14) | (b8 << 7) | b9
        return 10 + tagSize // ID3 头（10字节）+ 标签内容
    }
    
    // MARK: - 解析 FLAC Metadata Blocks
    // FLAC 文件由若干 Metadata Block 组成，每个 block 有类型编号
    // 类型 0 = STREAMINFO，类型 4 = VORBIS_COMMENT，类型 6 = PICTURE
    private static func parseFLACMetadataBlocks(data: Data, track: FLACTrack) {
        var offset = 4 // 跳过 "fLaC" 标识（4字节）
        
        while offset + 4 <= data.count {
            let headerByte = data[offset]
            let blockType = headerByte & 0x7F       // 低 7 位是块类型
            let isLast = (headerByte & 0x80) != 0   // 最高位表示是否是最后一个块
            
            // 块大小：接下来 3 个字节，大端序
            let blockSize = Int(data[offset+1]) << 16
                          | Int(data[offset+2]) << 8
                          | Int(data[offset+3])
            offset += 4 // 跳过 4 字节头部
            
            guard offset + blockSize <= data.count else { break }
            let blockData = data[offset..<offset+blockSize]
            
            switch blockType {
            case 4: // VORBIS_COMMENT：包含标题、艺术家等文字元数据
                parseVorbisComment(Data(blockData), track: track)
            case 6: // PICTURE：封面图片
                parsePictureBlock(Data(blockData), track: track)
            default:
                break // 其他块类型暂不处理
            }
            
            offset += blockSize
            if isLast { break } // 最后一个 Metadata Block，后面就是音频数据
        }
    }
    
    // MARK: - 解析 Vorbis Comment 块
    // 格式：[vendor_length(4)] [vendor_string] [count(4)] [comment_length(4) comment_string] ...
    // 所有整数均为小端序（Little Endian）
    private static func parseVorbisComment(_ data: Data, track: FLACTrack) {
        var pos = 0
        guard pos + 4 <= data.count else { return }
        
        // 读取 vendor string 长度并跳过
        let vendorLen = readLE32(data, at: pos); pos += 4
        pos += vendorLen // 跳过 vendor string 内容
        
        guard pos + 4 <= data.count else { return }
        // 读取注释条目数量
        let commentCount = readLE32(data, at: pos); pos += 4
        
        // 逐条读取 "KEY=VALUE" 格式的注释
        for _ in 0..<commentCount {
            guard pos + 4 <= data.count else { break }
            let len = readLE32(data, at: pos); pos += 4
            guard pos + len <= data.count else { break }
            
            // 解码为 UTF-8 字符串
            if let comment = String(data: data.subdata(in: pos..<pos+len), encoding: .utf8) {
                let parts = comment.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].lowercased()
                    let value = String(parts[1])
                    // 根据键名填充对应字段
                    switch key {
                    case "title":       track.title = value
                    case "artist":      track.artist = value
                    case "album":       track.album = value
                    case "date":        track.year = value
                    case "tracknumber": track.trackNumber = value
                    case "genre":       track.genre = value
                    case "comment":     track.comment = value
                    case "lyrics", "unsyncedlyrics", "unsynced lyrics":
                        track.lyrics = value // 歌词字段（多种键名）
                    default: break
                    }
                }
            }
            pos += len
        }
    }
    
    // MARK: - 解析 PICTURE 块
    // 格式：[type(4)] [mime_len(4)] [mime] [desc_len(4)] [desc]
    //       [width(4)] [height(4)] [depth(4)] [colors(4)] [data_len(4)] [data]
    // 所有整数均为大端序（Big Endian）
    private static func parsePictureBlock(_ data: Data, track: FLACTrack) {
        var pos = 0
        guard pos + 4 <= data.count else { return }
        
        // 跳过图片类型（4字节，3 表示封面）
        pos += 4
        
        // 读取 MIME 类型
        guard pos + 4 <= data.count else { return }
        let mimeLen = readBE32(data, at: pos); pos += 4
        guard pos + mimeLen <= data.count else { return }
        let mime = String(data: data.subdata(in: pos..<pos+mimeLen), encoding: .utf8) ?? "image/jpeg"
        pos += mimeLen
        
        // 跳过描述字符串
        guard pos + 4 <= data.count else { return }
        let descLen = readBE32(data, at: pos); pos += 4
        pos += descLen
        
        // 跳过宽度、高度、色深、颜色数（各 4 字节，共 16 字节）
        pos += 16
        
        // 读取图片数据
        guard pos + 4 <= data.count else { return }
        let imgLen = readBE32(data, at: pos); pos += 4
        guard pos + imgLen <= data.count else { return }
        
        track.flacCoverData = data.subdata(in: pos..<pos+imgLen)
        track.flacCoverMime = mime
    }
    
    // MARK: - 解析 ID3 标签（文件头部）
    // ID3v2 格式：[ID3 标识(3)] [版本(2)] [标志(1)] [大小(4 syncsafe)] [帧数据...]
    private static func parseID3Tag(data: Data, track: FLACTrack) {
        guard data.count >= 10 else { return }
        
        var pos = 10 // 跳过 10 字节的 ID3 头部
        let tagEnd = findFLACStart(in: data) // ID3 标签结束位置
        
        // 逐帧读取 ID3 帧
        while pos + 10 <= tagEnd && pos + 10 <= data.count {
            // 帧 ID：4 个 ASCII 字符
            guard let frameID = String(data: data.subdata(in: pos..<pos+4), encoding: .ascii),
                  frameID.first?.isLetter == true else { break }
            
            // 帧大小：4 字节大端序
            let frameSize = Int(data[pos+4]) << 24 | Int(data[pos+5]) << 16
                          | Int(data[pos+6]) << 8  | Int(data[pos+7])
            pos += 10 // 跳过帧头部（4+4+2 字节）
            
            guard frameSize > 0, pos + frameSize <= data.count else { break }
            let frameData = data.subdata(in: pos..<pos+frameSize)
            
            switch frameID {
            case "TIT2": // 标题
                track.id3Title = decodeID3String(frameData)
            case "TPE1": // 艺术家
                track.id3Artist = decodeID3String(frameData)
            case "TALB": // 专辑
                track.id3Album = decodeID3String(frameData)
            case "TYER", "TDRC": // 年份
                track.id3Year = decodeID3String(frameData)
            case "APIC": // 封面图片
                track.id3CoverData = parseAPICFrame(frameData)
            default:
                break
            }
            
            pos += frameSize
        }
    }
    
    // MARK: - 解析 ID3 APIC 帧（封面图片帧）
    // 格式：[编码(1)] [MIME(变长，以\0结尾)] [图片类型(1)] [描述(变长，以\0结尾)] [图片数据]
    private static func parseAPICFrame(_ data: Data) -> Data? {
        guard data.count > 1 else { return nil }
        var pos = 1 // 跳过编码字节
        
        // 找到 MIME 类型结尾的 \0
        while pos < data.count && data[pos] != 0x00 { pos += 1 }
        pos += 1 // 跳过 \0
        pos += 1 // 跳过图片类型字节
        
        // 找到描述结尾的 \0
        while pos < data.count && data[pos] != 0x00 { pos += 1 }
        pos += 1 // 跳过 \0
        
        guard pos < data.count else { return nil }
        return data.subdata(in: pos..<data.count) // 剩余部分就是图片数据
    }
    
    // MARK: - 解码 ID3 文本帧
    // ID3 文本帧第一个字节是编码标识：0=Latin-1, 1=UTF-16, 2=UTF-16BE, 3=UTF-8
    private static func decodeID3String(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        let encoding: String.Encoding
        switch data[0] {
        case 0: encoding = .isoLatin1
        case 1: encoding = .utf16
        case 2: encoding = .utf16BigEndian
        case 3: encoding = .utf8
        default: encoding = .utf8
        }
        return String(data: data.dropFirst(), encoding: encoding)?
            .trimmingCharacters(in: .controlCharacters) ?? ""
    }
    
    // MARK: - 工具函数：读取小端序 32 位整数
    static func readLE32(_ data: Data, at pos: Int) -> Int {
        guard pos + 4 <= data.count else { return 0 }
        return Int(data[pos])
             | Int(data[pos+1]) << 8
             | Int(data[pos+2]) << 16
             | Int(data[pos+3]) << 24
    }
    
    // MARK: - 工具函数：读取大端序 32 位整数
    static func readBE32(_ data: Data, at pos: Int) -> Int {
        guard pos + 4 <= data.count else { return 0 }
        return Int(data[pos])   << 24
             | Int(data[pos+1]) << 16
             | Int(data[pos+2]) << 8
             | Int(data[pos+3])
    }
    
    // MARK: - 公开方法：将 FLAC 封面同步写入 ID3 标签
    // 策略：在文件最开头插入/替换 ID3 标签，保持 FLAC 音频数据完全不变
    static func syncCoverToID3(track: FLACTrack, settings: AppSettings) throws {
        guard let coverData = track.flacCoverData else {
            throw FLACError.noCoverFound
        }
        
        guard let fileData = try? Data(contentsOf: track.url) else {
            throw FLACError.fileReadError
        }
        
        // 备份文件（如果设置开启）
        if settings.enableBackup {
            // 使用指定备份目录，或默认同目录
            let backupDir = AppSettings.shared.backupDirectory
                ?? track.url.deletingLastPathComponent()
            let backupURL = backupDir
                .appendingPathComponent(track.url.lastPathComponent)
                .appendingPathExtension("bak")
            try? fileData.write(to: backupURL)
        }
        // 找到 FLAC 数据的起始位置（如果已有 ID3 则跳过）
        var flacStart = 0
        if fileData.prefix(3) == Data([0x49, 0x44, 0x33]) {
            flacStart = findFLACStart(in: fileData)
        }
        let flacData = fileData.dropFirst(flacStart)
        
        // 判断封面实际格式（WebP 实际头是 RIFF）
        let mime: [UInt8]
        if coverData.prefix(4) == Data([0x52, 0x49, 0x46, 0x46]) {
            mime = Array("image/webp".utf8)
        } else if coverData.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]) {
            mime = Array("image/png".utf8)
        } else {
            mime = Array("image/jpeg".utf8)
        }
        
        // 构建新的 ID3 标签并拼接 FLAC 数据
        let id3Tag = buildID3Tag(coverData: Array(coverData), mime: mime,
                                 title: track.title, artist: track.artist,
                                 album: track.album, year: track.year)
        var result = Data(id3Tag)
        result.append(contentsOf: flacData)
        
        // 写回文件
        try result.write(to: track.url)
        
        // 更新内存中的状态
        track.id3CoverData = coverData
        track.hasID3Tag = true
    }
    
    // MARK: - 构建完整 ID3v2.3 标签
    // 包含封面（APIC）和文字信息（TIT2/TPE1/TALB/TYER）
    static func buildID3Tag(coverData: [UInt8], mime: [UInt8],
                            title: String, artist: String,
                            album: String, year: String) -> [UInt8] {
        var frames: [UInt8] = []
        
        // 添加封面帧 APIC
        frames += buildAPICFrame(imageData: coverData, mime: mime)
        
        // 添加文字帧（如果有内容）
        if !title.isEmpty  { frames += buildTextFrame("TIT2", value: title)  }
        if !artist.isEmpty { frames += buildTextFrame("TPE1", value: artist) }
        if !album.isEmpty  { frames += buildTextFrame("TALB", value: album)  }
        if !year.isEmpty   { frames += buildTextFrame("TYER", value: year)   }
        
        // 计算 syncsafe 大小并构建头部
        let size = frames.count
        let syncsafe: [UInt8] = [
            UInt8((size >> 21) & 0x7F),
            UInt8((size >> 14) & 0x7F),
            UInt8((size >> 7)  & 0x7F),
            UInt8(size & 0x7F)
        ]
        // ID3 头部：标识(3) + 版本 2.3(2) + 标志(1) + 大小(4 syncsafe)
        return Array("ID3".utf8) + [0x03, 0x00, 0x00] + syncsafe + frames
    }
    
    // MARK: - 构建 APIC 封面帧
    private static func buildAPICFrame(imageData: [UInt8], mime: [UInt8]) -> [UInt8] {
        // 帧内容：编码(0=Latin-1) + MIME + \0 + 图片类型(3=封面) + 描述\0 + 图片数据
        let body: [UInt8] = [0x00] + mime + [0x00, 0x03, 0x00] + imageData
        let size = body.count
        // 帧头：帧ID(4) + 大小(4大端序) + 标志(2)
        return Array("APIC".utf8)
             + [UInt8((size>>24)&0xFF), UInt8((size>>16)&0xFF),
                UInt8((size>>8)&0xFF),  UInt8(size&0xFF)]
             + [0x00, 0x00] + body
    }
    
    // MARK: - 构建文字帧（TIT2/TPE1 等）
    private static func buildTextFrame(_ frameID: String, value: String) -> [UInt8] {
        // 编码字节 0x03 = UTF-8
        let body: [UInt8] = [0x03] + Array(value.utf8)
        let size = body.count
        return Array(frameID.utf8)
             + [UInt8((size>>24)&0xFF), UInt8((size>>16)&0xFF),
                UInt8((size>>8)&0xFF),  UInt8(size&0xFF)]
             + [0x00, 0x00] + body
    }
    
    // MARK: - 将元数据写回 FLAC Vorbis Comment 块
    static func saveVorbisComment(track: FLACTrack) throws {
        guard let data = try? Data(contentsOf: track.url) else {
            throw FLACError.fileReadError
        }
        
        // 找到 FLAC 数据起始位置
        var flacStart = 0
        if data.prefix(3) == Data([0x49, 0x44, 0x33]) {
            flacStart = findFLACStart(in: data)
        }
        
        // 构建新的 Vorbis Comment 块内容
        let newBlock = buildVorbisCommentBlock(track: track)
        
        // 在 FLAC Metadata Block 中找到并替换 VORBIS_COMMENT 块
        let flacData = Data(data[flacStart...])
        if let newFlacData = replaceVorbisComment(in: flacData, with: newBlock) {
            var result = Data(data[..<flacStart])
            result.append(newFlacData)
            try result.write(to: track.url)
        }
    }
    
    // MARK: - 构建 Vorbis Comment 块数据
    private static func buildVorbisCommentBlock(track: FLACTrack) -> Data {
        // vendor string
        let vendor = Array("FLACTagger".utf8)
        var body = writeLE32(vendor.count) + vendor
        
        // 注释条目
        var comments: [[UInt8]] = []
        func addComment(_ key: String, _ value: String) {
            if !value.isEmpty {
                comments.append(Array("\(key)=\(value)".utf8))
            }
        }
        addComment("TITLE",       track.title)
        addComment("ARTIST",      track.artist)
        addComment("ALBUM",       track.album)
        addComment("DATE",        track.year)
        addComment("TRACKNUMBER", track.trackNumber)
        addComment("GENRE",       track.genre)
        addComment("COMMENT",     track.comment)
        addComment("LYRICS",      track.lyrics)
        
        body += writeLE32(comments.count)
        for c in comments { body += writeLE32(c.count) + c }
        return Data(body)
    }
    
    // MARK: - 在 FLAC 数据中替换 Vorbis Comment 块
    private static func replaceVorbisComment(in data: Data, with newBlock: Data) -> Data? {
        var offset = 4 // 跳过 "fLaC"
        var result = Data(data[..<4])
        var found = false
        
        while offset + 4 <= data.count {
            let headerByte = data[offset]
            let blockType = headerByte & 0x7F
            let isLast = (headerByte & 0x80) != 0
            let blockSize = Int(data[offset+1]) << 16 | Int(data[offset+2]) << 8 | Int(data[offset+3])
            
            if blockType == 4 { // VORBIS_COMMENT
                // 用新块替换，保持 isLast 标志不变
                let newSize = newBlock.count
                let newHeader: [UInt8] = [
                    (isLast ? 0x84 : 0x04),
                    UInt8((newSize >> 16) & 0xFF),
                    UInt8((newSize >> 8) & 0xFF),
                    UInt8(newSize & 0xFF)
                ]
                result.append(contentsOf: newHeader)
                result.append(newBlock)
                found = true
            } else {
                result.append(data[offset..<offset+4+blockSize])
            }
            offset += 4 + blockSize
            if isLast { break }
        }
        
        if !found { return nil }
        // 追加音频数据
        result.append(data[offset...])
        return result
    }
    
    // MARK: - 工具：写小端序 32 位整数
    private static func writeLE32(_ value: Int) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
         UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
    }
}

// MARK: - 错误类型定义
enum FLACError: LocalizedError {
    case noCoverFound    // FLAC 文件中没有找到封面
    case fileReadError   // 文件读取失败
    case fileWriteError  // 文件写入失败
    
    var errorDescription: String? {
        switch self {
        case .noCoverFound:  return "FLAC 文件中没有内嵌封面"
        case .fileReadError: return "无法读取文件"
        case .fileWriteError: return "无法写入文件"
        }
    }
}
