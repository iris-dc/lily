import Testing
@testable import lily

/// The share the strip's ring shows while an attachment uploads: the file and its thumbnail as one total, so the
/// second PUT continues where the first ended. Pinned here because a stubbed `URLSession` reports no intermediate
/// bytes, so the session test can only see the final 1.
struct UploadProgressTests {
    private let progress = UploadProgress(fileBytes: 750, thumbnailBytes: 250)

    @Test func theFileShareIsItsPartOfTheTotal() {
        #expect(progress.total == 1000)
        #expect(progress.share(fileSent: 375) == 0.375)
        #expect(progress.share(fileSent: 750) == 0.75)
    }

    @Test func theThumbnailContinuesWhereTheFileEnded() {
        #expect(progress.share(thumbnailSent: 0) == 0.75)
        #expect(progress.share(thumbnailSent: 250) == 1)
    }

    @Test func aFileWithoutAThumbnailFillsTheRingAlone() {
        let fileOnly = UploadProgress(fileBytes: 1000, thumbnailBytes: 0)
        #expect(fileOnly.share(fileSent: 500) == 0.5)
        #expect(fileOnly.share(fileSent: 1000) == 1)
    }

    @Test func sharesAreCappedAtOne() {
        #expect(progress.share(fileSent: 5_000) == 1)
        #expect(progress.share(thumbnailSent: 5_000) == 1)
    }

    @Test func aZeroTotalAnswersOne() {
        let empty = UploadProgress(fileBytes: 0, thumbnailBytes: 0)
        #expect(empty.share(fileSent: 0) == 1)
        #expect(empty.share(thumbnailSent: 0) == 1)
    }

    @Test func sharesNeverDecreaseAcrossTheTwoPUTs() {
        let shares = [0, 300, 750].map { progress.share(fileSent: $0) }
            + [0, 100, 250].map { progress.share(thumbnailSent: $0) }

        #expect(zip(shares, shares.dropFirst()).allSatisfy { $0 <= $1 }, "\(shares)")
        #expect(shares.last == 1)
    }
}
