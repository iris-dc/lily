import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A video from the Photos picker as a file of the app's own: the picker's file is only good for the import closure,
/// so it is copied into the temporary directory there and the copy is what the preparer exports from.
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
