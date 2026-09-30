import Foundation
import Observation

/// Another person's profile and the one action on it: opening the direct conversation, which lands in Mine at once and
/// pushes its chat on the Chats tab. The caller's own profile shows no button.
@Observable
final class UserProfileViewModel {
    enum State: Equatable {
        case loading
        case loaded(UserProfile)
        /// The popup said what went wrong; the screen offers to try again.
        case failed
    }

    let destination: UserProfileDestination
    private(set) var state: State = .loading
    private(set) var isStartingConversation = false

    private let repository: any UserRepository
    private let identity: any IdentityProvider
    private let myGroups: MyGroupsStore
    private let navigation: AppNavigation
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private var hasLoggedOpen = false

    init(destination: UserProfileDestination,
         repository: any UserRepository,
         identity: any IdentityProvider,
         myGroups: MyGroupsStore,
         navigation: AppNavigation,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay) {
        self.destination = destination
        self.repository = repository
        self.identity = identity
        self.myGroups = myGroups
        self.navigation = navigation
        self.reporter = reporter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
    }

    var userID: String { destination.userId }

    /// The name the row that opened the profile carried, until the profile answers with the current one.
    var displayName: String { profile?.displayName ?? destination.displayName }

    var profile: UserProfile? {
        if case .loaded(let profile) = state { return profile }
        return nil
    }

    var isSelf: Bool { identity.currentUserID == userID }

    /// Anyone signed in may write to anyone but themselves, except from the conversation with them: that chat is one
    /// Back away and "Message" would only push it again (the group detail hides "Open chat" from its chat the same way).
    var canMessage: Bool { identity.currentUserID != nil && !isSelf && destination.context == .standalone }

    /// Loads the profile, or reloads it when the view's task restarts on the way back from a pushed group; a profile
    /// already on screen stays while the request runs and when it fails, as the event detail keeps its participants.
    func load() async {
        logOpenOnce()
        if profile == nil { state = .loading }
        do {
            state = .loaded(try await repository.profile(userID: userID))
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Loading profile \(userID) failed: \(error)")
            if profile == nil { state = .failed }
            reporter.report(error)
        }
    }

    /// One request at a time; `TRY_AGAIN` is repeated once (one id per pair, so a repeat answers the same room). The
    /// conversation goes into Mine before its chat opens, so the Chats tab lists it on the way back.
    func message() async {
        guard canMessage, !isStartingConversation else { return }
        isStartingConversation = true
        defer { isStartingConversation = false }
        do {
            let conversation = try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: logRetry) {
                try await repository.startConversation(with: userID)
            }
            myGroups.add(conversation)
            logger.info(.groups, "Conversation \(conversation.id) started with \(userID)")
            navigation.open(chat: conversation)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Starting a conversation with \(userID) failed: \(error)")
            reporter.report(error)
        }
    }

    /// One line per screen instance, however often the view's task restarts.
    private func logOpenOnce() {
        guard !hasLoggedOpen else { return }
        hasLoggedOpen = true
        logger.info(.groups, "Profile \(userID) opened")
    }

    private func logRetry() {
        logger.info(.groups, "Starting a conversation with \(userID) lost a race; retrying once")
    }
}
