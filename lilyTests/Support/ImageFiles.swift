import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// Facts a test reads off a picture file, and the picture files a test writes.
enum ImageFiles {
    /// The pixel size the file reports, read through ImageIO without decoding it.
    static func dimensions(of url: URL) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        return (width, height)
    }

    /// `image` encoded as `type` (PNG, GIF or JPEG), tagged with an EXIF `orientation` when one is given, as a camera
    /// tags a portrait shot: the pixels stay as drawn and the tag says how to turn them.
    static func encoded(_ image: CGImage, as type: UTType, orientation: Int? = nil) throws -> Data {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, orientation.map { [kCGImagePropertyOrientation: $0] as CFDictionary })
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// A picture of one gray, `width` x `height` 8-bit pixels, encoded as `type`: a few KB on disk however many pixels it
    /// declares, the shape of a pixel bomb.
    static func blankPictureData(width: Int, height: Int, type: UTType, orientation: Int? = nil) throws -> Data {
        let context = try #require(CGContext(data: nil,
                                             width: width,
                                             height: height,
                                             bitsPerComponent: 8,
                                             bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try encoded(try #require(context.makeImage()), as: type, orientation: orientation)
    }

    /// `blankPictureData` written to a file in `directory`, named by its size and type.
    static func blankPicture(width: Int,
                             height: Int,
                             type: UTType,
                             orientation: Int? = nil,
                             in directory: URL) throws -> URL {
        let url = directory.appending(path: "blank-\(width)x\(height).\(type.preferredFilenameExtension ?? "bin")")
        try blankPictureData(width: width, height: height, type: type, orientation: orientation).write(to: url)
        return url
    }

    /// A PNG that is its signature, an `IHDR` declaring `width` x `height` 8-bit gray pixels, one `IDAT` holding the
    /// zlib stream of a single byte and `IEND`: a few dozen bytes whose header claims any size a hostile file could,
    /// the shape of a declared-size bomb with nothing behind it.
    static func pngHeaderOnly(width: UInt32, height: UInt32) -> Data {
        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        var header = Data(width.bigEndianBytes + height.bigEndianBytes)
        header.append(contentsOf: [8, 0, 0, 0, 0])
        png.append(chunk("IHDR", header))
        png.append(chunk("IDAT", Data([0x78, 0x9C, 0x63, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01])))
        png.append(chunk("IEND", Data()))
        return png
    }

    /// One PNG chunk: the body's length, the type, the body and the CRC-32 of type and body, so the reader trusts it.
    private static func chunk(_ type: String, _ body: Data) -> Data {
        let typed = Data(type.utf8) + body
        return Data(UInt32(body.count).bigEndianBytes) + typed + Data(crc32(typed).bigEndianBytes)
    }

    /// zlib's CRC-32, bit by bit; the few bytes here need no table.
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xEDB8_8320 : 0)
            }
        }
        return ~crc
    }
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] { withUnsafeBytes(of: bigEndian, Array.init) }
}
