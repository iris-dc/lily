import Foundation

nonisolated extension AppBranding {
    /// The terms of use as the app shows them (Settings → Terms of use), one catalog key per heading and paragraph,
    /// like the privacy policy. They mirror the page Laurel serves at `AppConfig.Moderation.termsURL` section for
    /// section, fact for fact — a change to either side lands in both in the same change
    /// (`laurel/src/main/resources/pages/terms.html`) — minus the page's version stamp: agreement is by use, never
    /// a prompt (owner decision 2026-11-08), so no version is put to the reader and nothing asks to be accepted.
    enum Terms {
        typealias Section = Legal.Section
        typealias Paragraph = Legal.Paragraph

        /// The whole document in the page's order.
        static var sections: [Section] {
            [service, conduct, moderation, account, changes, contact]
        }

        static var service: Section {
            Section(title: localized("The service"), paragraphs: [
                Paragraph(body: localized("""
                    iskra lets you find and organise sport events, join groups and chat with their members, and \
                    enter or organise tournaments. By creating an account or using iskra you agree to these terms. \
                    How we handle your data is described in the privacy policy.
                    """))
            ])
        }

        static var conduct: Section {
            Section(title: localized("Your content and conduct"), paragraphs: [
                Paragraph(body: localized("""
                    You are responsible for what you post: event details, group names and descriptions, your \
                    display name, your "about you" text and your messages. iskra has zero tolerance for \
                    objectionable content and abusive users: harassment, threats, hate speech, sexual content, \
                    spam and impersonation are not allowed. Content that breaks these rules is removed and the \
                    accounts behind it are suspended or removed without notice.
                    """))
            ])
        }

        static var moderation: Section {
            Section(title: localized("Reporting and moderation"), paragraphs: [
                Paragraph(body: localized("""
                    Every message, group and profile can be reported from within the app, and you can block any \
                    user so their messages no longer reach you. Reports are reviewed and acted on within 24 hours; \
                    a moderator may delete content, remove or ban members, delete groups and events, and suspend \
                    accounts. Moderator actions, and event and account deletions, are recorded in an audit log, as \
                    the privacy policy describes.
                    """))
            ])
        }

        static var account: Section {
            Section(title: localized("Your account"), paragraphs: [
                Paragraph(body: localized("""
                    You may delete your account at any time in the app: Settings → Delete account. Deletion cannot \
                    be undone. It removes your sign-in identity and profile; groups you own pass to their \
                    longest-standing member or are deleted; upcoming games you host are cancelled and the players \
                    notified; your upcoming tournament entries are withdrawn and tournaments you organise are \
                    cancelled. Messages you wrote, and the results of games and tournaments you took part in, \
                    remain visible to the other participants, no longer shown with your name but under a neutral \
                    "Deleted user" label or a neutral placeholder name; for a bounded time your name can remain \
                    quoted inside other people's replies, invite notices and abuse reports. The details and the \
                    retention periods are in the privacy policy.
                    """))
            ])
        }

        /// Agreement is by use (owner decision 2026-11-08): a change never prompts, it applies to continued use.
        static var changes: Section {
            Section(title: Legal.changesTitle, paragraphs: [
                Paragraph(body: localized("""
                    When these terms change, we update them here. By continuing to use iskra after a change you \
                    agree to the updated terms.
                    """))
            ])
        }

        static var contact: Section {
            Section(title: localized("Contact"), paragraphs: [
                Paragraph(body: localized("""
                    Questions and complaints: support@iskra.red. The service is operated by the app's developer, \
                    reachable at that address.
                    """))
            ])
        }
    }
}
