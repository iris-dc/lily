import Foundation
import Testing
@testable import lily

struct GroupConfirmationTests {
    @Test func leaveAndDeleteNameTheGroupAndTheirButtons() {
        #expect(GroupConfirmation.leave.title(groupName: "Kickers").contains("Kickers"))
        #expect(GroupConfirmation.delete.title(groupName: "Kickers").contains("Kickers"))
        #expect(GroupConfirmation.leave.buttonTitle == "Leave group")
        #expect(GroupConfirmation.delete.buttonTitle == "Delete group")
    }

    @Test func removeAndBanNameTheMemberNotTheGroup() {
        let member = GroupMember.fixture(userId: "u-2")

        let removal = GroupConfirmation.remove(member).title(groupName: "Kickers")
        let ban = GroupConfirmation.ban(member).title(groupName: "Kickers")

        #expect(removal.contains("Member u-2") && !removal.contains("Kickers"))
        #expect(ban.contains("Member u-2") && !ban.contains("Kickers"))
        #expect(GroupConfirmation.remove(member).buttonTitle == "Remove")
        #expect(GroupConfirmation.ban(member).buttonTitle == "Ban")
    }

    @Test func confirmationsOnTheSameMemberStayDistinct() {
        let member = GroupMember.fixture(userId: "u-2")

        #expect(GroupConfirmation.remove(member) != GroupConfirmation.ban(member))
        #expect(GroupConfirmation.remove(member).id != GroupConfirmation.ban(member).id)
    }
}
