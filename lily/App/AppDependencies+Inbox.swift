import Foundation

extension AppDependencies {
    var inboxRepository: any InboxRepository { groups.inboxRepository }
    var inbox: InboxStore { groups.inbox }

    /// The inbox screen over the shared store; an accepted invite's group goes into Mine and its chat opens.
    func makeInboxViewModel() -> InboxViewModel {
        InboxViewModel(store: inbox,
                       repository: inboxRepository,
                       opener: eventOpener,
                       myGroups: myGroups,
                       navigation: navigation,
                       reporter: groups.errorReporter,
                       logger: logger)
    }
}
