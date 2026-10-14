import Testing
@testable import lily

struct InitialsTests {
    @Test(arguments: [
        ("Kreuzberg Kickers", "KK"),
        ("Marta", "M"),
        ("sunday padel crew", "SP"),
        ("", ""),
    ])
    func initialsTakeTheFirstLettersOfTheFirstTwoWords(name: String, expected: String) {
        #expect(name.initials == expected)
    }
}
