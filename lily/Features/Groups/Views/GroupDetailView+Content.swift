import SwiftUI

/// The redesigned detail's blocks: the centered header, the place card, the People card and the pinned action bar.
/// In an extension so the view's main file keeps the wiring alone.
extension GroupDetailView {
    private typealias People = AppBranding.People

    /// The group's mark (its sport, or the generic mark when it has none), its name, and what it is in one line:
    /// visibility and size.
    var header: some View {
        DetailHeader(symbolName: group.type?.symbolName ?? DesignTokens.Symbols.groups,
                     tint: group.type == nil ? .secondary : .sport,
                     title: group.name,
                     caption: Copy.caption([group.visibility.displayName, Copy.members(group.memberCount)]))
    }

    /// Where the group plays, with the distance when the position is known; a group without a place has no card.
    @ViewBuilder var detailsSection: some View {
        if let location = group.location {
            DetailSection(title: People.detailsSection) {
                GlassCard {
                    PlaceLine(name: location.name,
                              distance: group.distance(from: events.userLocation)?.roadText())
                }
            }
        }
    }

    /// Who runs the group and who is in: the first members' circles and the count; each row opens the roster for
    /// whoever may see it.
    var peopleSection: some View {
        DetailSection(title: People.peopleSection) {
            GlassCard {
                VStack(spacing: 0) {
                    PeopleSummaryRow(title: People.organisedByRow,
                                     names: [group.ownerName],
                                     detail: group.ownerName,
                                     destination: membersDestination,
                                     identifier: AccessibilityIdentifiers.peopleHostingRow)
                    Divider()
                    PeopleSummaryRow(title: Copy.membersSection,
                                     names: members?.members.map(\.displayName) ?? [],
                                     detail: "\(group.memberCount)",
                                     destination: membersDestination,
                                     identifier: AccessibilityIdentifiers.peopleGoingRow)
                }
            }
        }
    }

    @ViewBuilder var aboutSection: some View {
        if let description = group.description {
            DetailSection(title: People.aboutSection) {
                GlassCard {
                    Text(description).font(.body)
                }
            }
        }
    }

    private var membersDestination: GroupMembersDestination? {
        viewModel.showsRoster ? GroupMembersDestination(group: group) : nil
    }

    /// Invite and create-event as quiet circles, then the one thing to do: members open the chat, outsiders join (a
    /// guest through sign-in), and whoever cannot act is told why in the bar's notice.
    var actionBar: some View {
        DetailActionBar {
            if viewModel.access.canInvite(in: group) {
                Button {
                    presentedSheet = .invite
                } label: {
                    Image(systemName: DesignTokens.Symbols.invite)
                }
                .lilyGlassIconButton()
                .accessibilityLabel(Copy.invite)
                .accessibilityIdentifier(AccessibilityIdentifiers.groupInvite)
            }
            if viewModel.access.canCreateEvents(in: group) {
                Button {
                    presentCreateEvent()
                } label: {
                    Image(systemName: DesignTokens.Symbols.addEvent)
                }
                .lilyGlassIconButton()
                .accessibilityLabel(Copy.createGame)
                .accessibilityIdentifier(AccessibilityIdentifiers.groupCreateEvent)
            }
        } primary: {
            primaryControl
        }
    }

    @ViewBuilder private var primaryControl: some View {
        switch viewModel.access {
        case .member, .conversation, .room:
            if viewModel.showsOpenChat {
                Button {
                    viewModel.openChat()
                } label: {
                    Label(Copy.openChat, systemImage: DesignTokens.Symbols.chat)
                }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupOpenChat)
            }
        case .canJoin:
            BusyButton(Copy.joinGroup, isBusy: viewModel.isBusy) { await viewModel.join() }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupJoin)
        case .guest:
            Button(Copy.joinGroup) { presentedSheet = .signIn }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupJoin)
        case .inviteOnly:
            DetailBarNotice(text: Copy.inviteOnly)
        case .full:
            BusyButton(Copy.groupFull, isBusy: viewModel.isBusy)
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupJoin)
        }
    }
}
