import Foundation
import Testing
@testable import lily

/// `GET /api/me/deletion-plan`: the contract's five advisory counts, decoded as pinned in `ContractSamples`.
struct DeletionPlanTests {
    @Test func theContractsCountsDecode() throws {
        let plan = try ContractSamples.decode(DeletionPlan.self, from: ContractSamples.deletionPlan)
        #expect(plan == DeletionPlan(groupsTransferring: 2,
                                     groupsDeleted: 1,
                                     eventsCancelled: 1,
                                     entriesWithdrawn: 3,
                                     tournamentsCancelled: 0))
    }

    @Test func thePlanRoundTripsUnderTheWireCoding() throws {
        let plan = DeletionPlan(groupsTransferring: 0,
                                groupsDeleted: 0,
                                eventsCancelled: 0,
                                entriesWithdrawn: 0,
                                tournamentsCancelled: 0)
        let decoded = try APIJSONCoding.makeDecoder().decode(DeletionPlan.self, from: APIJSONCoding.makeEncoder().encode(plan))
        #expect(decoded == plan)
    }
}

/// The delete flow's inverted success check: a 401 or `USER_NOT_FOUND` means the deletion landed.
struct DeletionSettleTests {
    @Test func a401OrUserNotFoundIsLanded() {
        #expect(DeletionSettle.isLanded(.sessionExpired), "any 401 maps to .sessionExpired before the body is read")
        #expect(DeletionSettle.isLanded(.userNotFound))
    }

    @Test func anythingElseIsNotSettled() {
        #expect(!DeletionSettle.isLanded(.network))
        #expect(!DeletionSettle.isLanded(.rateLimited(retryAfter: nil)))
        #expect(!DeletionSettle.isLanded(.accountDeletionFailed))
        #expect(!DeletionSettle.isLanded(.unknown))
    }
}
