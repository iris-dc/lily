import Foundation
import Observation

/// Owns the draft of a new group and sends it once. The draft judges itself (`GroupDraft.issues`); this proposes the
/// device's position as the spot, decides when the draft may go, keeps a second tap from sending it twice, and hands
/// the created group to Mine and the sheet's caller.
@Observable
final class CreateGroupViewModel {
    var draft = GroupDraft()
    private(set) var isSubmitting = false
    /// Set once the backend answered; the sheet dismisses when it appears.
    private(set) var createdGroup: SportGroup?

    private let repository: any GroupRepository
    private let identity: any IdentityProvider
    private let store: MyGroupsStore
    private let locationService: any LocationService
    private let geocoder: any GeocodingService
    private let logger: any Logging
    /// The user's position as `prepare()` read it: the place lookups' bias once the draft has no spot of its own.
    private var position: Coordinate?
    /// A `.network` or `.groupCreationFailed` (which also covers an id another user owns) leaves the outcome unknown;
    /// the group is ours when the caller owns what the backend holds under the draft's id; a `.createIdReused` sends
    /// the draft as an update under that id.
    private let flow: CreateFlow<SportGroup>
    private let onCreated: @MainActor (SportGroup) -> Void

    init(repository: any GroupRepository,
         identity: any IdentityProvider,
         store: MyGroupsStore,
         locationService: any LocationService,
         geocoder: any GeocodingService = MockGeocodingService(),
         errorCenter: ErrorCenter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         onCreated: @escaping @MainActor (SportGroup) -> Void) {
        self.repository = repository
        self.identity = identity
        self.store = store
        self.locationService = locationService
        self.geocoder = geocoder
        self.logger = logger
        self.onCreated = onCreated
        flow = CreateFlow(noun: "group",
                          category: .groups,
                          logger: logger,
                          tryAgainDelay: tryAgainDelay,
                          report: { errorCenter.report($0) },
                          leavesOutcomeUnknown: { $0 == .network || $0 == .groupCreationFailed },
                          notFound: .groupNotFound,
                          lookup: { try await repository.group(id: $0) },
                          isOurs: { $0.role == .owner })
    }

    /// Proposes the device's position as the group's spot, as the event form does, so naming the place is all a
    /// public group asks; a spot already chosen (the map was opened first) is kept.
    func prepare() async {
        guard draft.coordinate == nil else { return }
        let position = await locationService.currentLocation()
        self.position = position
        if draft.coordinate == nil { draft.coordinate = position }
        logger.debug(.location, position == nil ? "No position for the new group; the spot is set on the map"
                                                : "New group proposed at the user's position")
    }

    /// Biased to the draft's spot, else the user's position, so a venue name finds the one nearby.
    func placeSuggestions(for query: String) async -> [PlaceSuggestion] {
        await geocoder.suggestions(for: query, near: draft.coordinate ?? position)
    }

    var issues: [GroupDraft.Issue] { draft.issues }

    var canSubmit: Bool { !isSubmitting && draft.isValid }

    /// Sends the draft. A call while one is in flight is dropped; a dismissed sheet (cancellation) stays quiet; a
    /// failure goes to the popup unless the backend turns out to have the group already (`CreateFlow`). The same
    /// `clientId` travels with every attempt, so a retry after a lost answer finds the group, or updates it with the
    /// latest details, instead of creating a second one. An answer for a caller who signed out or changed meanwhile is
    /// dropped: nothing enters Mine, nothing opens (a guest's caller is nil; the client refuses their write).
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let caller = identity.currentUserID
        let created = await flow.submit(clientID: draft.clientId,
                                        describing: { "(\($0.visibility.rawValue))" },
                                        send: { try await repository.create(draft) },
                                        update: { try await repository.update(id: draft.clientId, draft) })
        guard let created else { return }
        if let caller, !identity.isStillCaller(caller, orDrop: "Create answer", logger: logger) { return }
        accept(created)
    }

    private func accept(_ group: SportGroup) {
        createdGroup = group
        store.add(group)
        onCreated(group)
    }
}

extension CreateGroupViewModel: GroupDraftEditing {
    var isDone: Bool { createdGroup != nil }
}
