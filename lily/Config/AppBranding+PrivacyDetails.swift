import Foundation

nonisolated extension AppBranding.Privacy {
    /// "What we store, and why": one paragraph per store, each opened by its bold lead, as the served page writes them.
    static var storage: Section {
        Section(title: localized("What we store, and why"),
                paragraphs: [account, creations, devices, statistics, feedbackKept, moderationKept, position, logs])
    }

    /// "Deleting your account": the in-app flow, the tombstones and bounded traces, and what outlives deletion.
    static var deletion: Section {
        Section(title: localized("Deleting your account"),
                paragraphs: [deletionFlow, deletionTraces, deletionRemainder])
    }

    private static var account: Paragraph {
        Paragraph(lead: localized("Your account."), body: localized("""
            Your email address and password are held by our sign-in provider, AWS Cognito; our own servers see only \
            your account identifier, never your password. We store the display name you choose and, if you write \
            one, a short "about you" text; the list of users you block; the terms version you accepted and when; \
            and per-sport counters derived from what you view, join and host, which help order your feed by \
            relevance. We need this to run your account (performance of our contract with you), and all of it is \
            deleted with your account.
            """))
    }

    private static var creations: Paragraph {
        Paragraph(lead: localized("What you create."), body: localized("""
            Groups, events, tournament entries and results, chat messages and their attachments are stored so the \
            people you share them with can see them. Chat messages are kept at most 365 days, and attachments \
            (pictures, videos and files) are removed from storage at most 365 days after upload. Notices in your \
            in-app inbox are kept 90 days, and records of your participation in an event are kept 365 days after \
            the event's start.
            """))
    }

    private static var devices: Paragraph {
        Paragraph(lead: localized("Your devices."), body: localized("""
            If you allow notifications, we store your device's push token, together with its platform, the app's \
            version and the language it shows, so notifications arrive and are worded in your language. A device's \
            record is removed 180 days after its last registration — the app refreshes the registration while you \
            stay signed in — and all your devices are deleted when you delete your account.
            """))
    }

    private static var statistics: Paragraph {
        Paragraph(lead: localized("Usage statistics."), body: localized("""
            We record which events, groups and tournaments you view, create, join and leave, when you open a chat, \
            run a search, view a list, send, accept or decline an invite, start a conversation or record a match \
            result, and the shape of the filters you use — identifiers and categories tied to your account \
            identifier, never coordinates, message text or names. These records order what you see by relevance \
            and show us how the app is used (our legitimate interest in running a useful service); they expire at \
            most 180 days after they are recorded.
            """))
    }

    private static var feedbackKept: Paragraph {
        Paragraph(lead: localized("Feedback."), body: localized("""
            A message you send through the contact form, with the reply email you may choose to include, is kept \
            at most 365 days.
            """))
    }

    private static var moderationKept: Paragraph {
        Paragraph(lead: localized("Moderation."), body: localized("""
            An abuse report, including a copy of the reported content so it can be reviewed even after a deletion, \
            is kept 180 days. Moderator actions, and every event and account deletion, are written to an audit log \
            that holds identifiers and short labels of what changed — an event's title, a group's or tournament's \
            name, a status, a reason — never message text or email addresses, and has no expiry, because it is \
            what holds moderators accountable (our legitimate interest in keeping the service safe).
            """))
    }

    private static var position: Paragraph {
        Paragraph(lead: localized("Approximate position."), body: localized("""
            Only if you grant the app location access, it sends your position, rounded to about one kilometre, \
            with requests for nearby events so they can be ordered by distance, and a coarse home area derived \
            from it is kept for the same ordering. We never store your exact position or any movement history. \
            You can withdraw this at any time in your device's settings (consent).
            """))
    }

    private static var logs: Paragraph {
        Paragraph(lead: localized("Technical logs."), body: localized("""
            Our servers keep operational logs for debugging and abuse protection; they can include your account \
            identifier and, when a request is refused for being too frequent, your network address. They are \
            deleted after about two weeks.
            """))
    }

    private static var deletionFlow: Paragraph {
        Paragraph(body: localized("""
            You can delete your account in the app at any time: Settings → Delete account. It cannot be undone. \
            Your account is disabled and signed out everywhere at once and can never be used again; the erasure \
            then completes in the background, normally within minutes. It deletes your profile (name, about text, \
            preference counters, blocked list, home area) and your notification devices, and removes your sign-in \
            identity (email and password) from the sign-in provider as its final step. Groups you own pass to \
            their longest-standing member or are deleted; upcoming games you host are cancelled and the players \
            notified; your upcoming tournament entries are withdrawn and tournaments you organise are cancelled.
            """))
    }

    private static var deletionTraces: Paragraph {
        Paragraph(body: localized("""
            Messages you wrote, and games and tournaments you took part in, remain visible to the other \
            participants but are no longer shown with your name: they carry a neutral "Deleted user" label or a \
            neutral placeholder name instead. A few traces of your name do survive for a bounded time inside other \
            people's data, where nothing can look them up: a reply or pinned message that quoted one of your \
            messages keeps the quoted name until chat retention removes it (at most 365 days), an invite notice \
            that named you as its sender expires with the recipient's inbox (90 days), and an abuse report's \
            snapshot keeps what it recorded until the report expires (180 days). Everything else runs out its \
            ordinary retention: chat messages and their attachments at most 365 days, inbox notices 90 days, abuse \
            reports 180 days, contact-form messages 365 days — the reply email you attached is removed at \
            deletion, the message itself expires on its schedule — and participation records 365 days after an \
            event's start.
            """))
    }

    private static var deletionRemainder: Paragraph {
        Paragraph(body: localized("""
            What outlives deletion carries your old account identifier, never your email: the audit log keeps its \
            entries in the identifier-and-short-label form described above, with no expiry, and gains one \
            permanent entry recording that the deletion completed; usage statistics expire at most 180 days after \
            they were recorded; and a minimal identifier-only marker of the completed deletion keeps the deleted \
            account refused for 30 days and then expires.
            """))
    }
}
