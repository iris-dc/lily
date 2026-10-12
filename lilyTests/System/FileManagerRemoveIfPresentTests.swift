import Foundation
import Testing
@testable import lily

/// `removeItemIfPresent` takes a file or a directory away when there is one, says nothing about nothing, and still
/// throws when the file system refuses, so a stuck file never passes for gone.
@MainActor
struct FileManagerRemoveIfPresentTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "remove-if-present-\(UUID().uuidString)")

    @Test func nothingThereIsNoError() {
        #expect(throws: Never.self) { try FileManager.default.removeItemIfPresent(at: root) }
    }

    @Test func aPresentDirectoryGoesWithItsContents() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("bytes".utf8).write(to: root.appending(path: "file"))

        try FileManager.default.removeItemIfPresent(at: root)

        #expect(!FileManager.default.fileExists(atPath: root.path()))
    }

    @Test func aRefusedRemovalThrows() throws {
        let file = root.appending(path: "file")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("bytes".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path())
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path())
            try? FileManager.default.removeItem(at: root)
        }

        #expect(throws: (any Error).self) { try FileManager.default.removeItemIfPresent(at: file) }
        #expect(FileManager.default.fileExists(atPath: file.path()), "what would not go is still there")
    }
}
