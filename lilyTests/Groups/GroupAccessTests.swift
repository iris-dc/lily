import Foundation
import Testing
@testable import lily

/// The permission matrix of plan section 5, as the screens read it.
struct GroupAccessTests {
    struct Case: CustomTestStringConvertible {
        let name: String
        let group: SportGroup
        let userID: String?
        let expected: GroupAccess

        var testDescription: String { name }
    }

    private static let full = SportGroup.fixture(memberCount: 12, maxMembers: 12)
    private static let cases: [Case] = [
        Case(name: "guest sees a public group", group: .fixture(), userID: nil, expected: .guest),
        Case(name: "guest sees a private group", group: .fixture(visibility: .private), userID: nil, expected: .guest),
        Case(name: "signed in, public, not a member", group: .fixture(), userID: "u", expected: .canJoin),
        Case(name: "signed in, private, not a member", group: .fixture(visibility: .private), userID: "u", expected: .inviteOnly),
        Case(name: "member", group: .fixture(role: .member), userID: "u", expected: .member(.member)),
        Case(name: "admin", group: .fixture(role: .admin), userID: "u", expected: .member(.admin)),
        Case(name: "owner", group: .fixture(visibility: .private, role: .owner), userID: "u", expected: .member(.owner)),
        Case(name: "full group, not a member", group: full, userID: "u", expected: .full),
        Case(name: "full group, member",
             group: .fixture(memberCount: 12, maxMembers: 12, role: .member),
             userID: "u",
             expected: .member(.member)),
        Case(name: "full group, guest", group: full, userID: nil, expected: .guest),
    ]

    @Test(arguments: cases)
    func accessFollowsTheMatrix(_ testCase: Case) {
        #expect(GroupAccess(group: testCase.group, userID: testCase.userID) == testCase.expected)
    }

    /// Chat and the roster are members-only in every group; guests and outsiders get neither.
    @Test(arguments: [GroupAccess.guest, .canJoin, .inviteOnly, .full])
    func outsidersCanDoNothingInside(access: GroupAccess) {
        let group = SportGroup.fixture()
        #expect(!access.canChat && !access.canSeeMembers && !access.canLeave && !access.canEdit)
        #expect(!access.canDelete && !access.canChangeRoles)
        #expect(!access.canCreateEvents(in: group) && !access.canInvite(in: group))
        #expect(!access.canRemove(.member) && !access.canBan(.member))
    }

    @Test func membersChatSeeTheRosterAndLeave() {
        let member = GroupAccess.member(.member)
        #expect(member.canChat && member.canSeeMembers && member.canLeave)
        #expect(!member.canEdit && !member.canDelete && !member.canChangeRoles)
        #expect(!member.canRemove(.member) && !member.canBan(.member))
    }

    /// Members create games and invite only when the group's settings allow it; admins and owners always.
    @Test func groupSettingsGateMembersNotAdmins() {
        let open = SportGroup.fixture(membersCanCreateEvents: true, membersCanInvite: true)
        let closed = SportGroup.fixture(membersCanCreateEvents: false, membersCanInvite: false)

        #expect(GroupAccess.member(.member).canCreateEvents(in: open) && GroupAccess.member(.member).canInvite(in: open))
        #expect(!GroupAccess.member(.member).canCreateEvents(in: closed) && !GroupAccess.member(.member).canInvite(in: closed))
        for role in [MemberRole.admin, .owner] {
            #expect(GroupAccess.member(role).canCreateEvents(in: closed) && GroupAccess.member(role).canInvite(in: closed))
        }
    }

    @Test func adminsRunTheGroupOwnersOwnIt() {
        let admin = GroupAccess.member(.admin)
        #expect(admin.canEdit && admin.canLeave && !admin.canDelete && !admin.canChangeRoles)
        #expect(admin.canRemove(.member) && admin.canBan(.member))
        #expect(!admin.canRemove(.admin) && !admin.canBan(.admin) && !admin.canRemove(.owner))

        let owner = GroupAccess.member(.owner)
        #expect(owner.canEdit && owner.canDelete && owner.canChangeRoles && !owner.canLeave)
        #expect(owner.canRemove(.member) && owner.canRemove(.admin) && owner.canBan(.member) && owner.canBan(.admin))
        #expect(!owner.canRemove(.owner) && !owner.canBan(.owner) && !owner.canRemove(.banned))
    }
}
