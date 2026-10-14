import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A video from the Photos picker, copied into the temporary directory inside the import closure, the only place the
/// picker's file is readable. The copy belongs to the composer (`MediaSource.ownedFile`), which removes it once the
/// preparer is done.
nonisolated struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appending(path: "picked-\(UUID().uuidString.lowercased()).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}
