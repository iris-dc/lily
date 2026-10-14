import Foundation

/// Where a Profile choice survives a relaunch.
protocol ChoiceStore<Choice> {
    associatedtype Choice: StoredChoice
    func load() -> Choice
    func save(_ choice: Choice)
    func clear()
}
