import Foundation

nonisolated extension AppBranding {
    /// The privacy policy as the app shows it (Settings → Privacy policy), one catalog key per heading and paragraph,
    /// so the screen is data-driven and the copy translates like everything else. It mirrors the page Laurel serves
    /// at `AppConfig.Moderation.privacyURL` — the canonical address App Store Connect points at — section for section,
    /// fact for fact: a change to either side lands in both in the same change
    /// (`laurel/src/main/resources/pages/privacy.html`). The page's date line and its self-referencing footer stay on
    /// the page alone (owner decision 2026-11-08: the in-app screen carries the sections and nothing else).
    enum Privacy {
        typealias Section = Legal.Section
        typealias Paragraph = Legal.Paragraph

        /// The whole policy in the page's order; the two long sections live in `AppBranding+PrivacyDetails.swift`.
        static var sections: [Section] {
            [whoWeAre, storage, residency, sharing, deletion, rights, changes]
        }

        static var whoWeAre: Section {
            Section(title: localized("Who we are"), paragraphs: [
                Paragraph(body: localized("""
                    iskra is a meetup app for sport events: you find and join games near you, run groups with their \
                    own chat, and enter or organise tournaments. The service is operated by its developer. For every \
                    matter in this policy, including requests about your data, contact support@iskra.red.
                    """))
            ])
        }

        static var residency: Section {
            Section(title: localized("Where your data lives"), paragraphs: [
                Paragraph(body: localized("""
                    Everything is stored in the European Union, in Amazon Web Services' Frankfurt region \
                    (eu-central-1): your sign-in identity in AWS Cognito, everything else in AWS databases and \
                    storage in the same region. One exception leaves the EU: when Apple delivers a push \
                    notification, your device's token and the notification's content pass through Apple's systems, \
                    which may process them outside the EU; that transfer is covered by standard contractual clauses \
                    in our agreement with Apple.
                    """))
            ])
        }

        static var sharing: Section {
            Section(title: localized("Who we share data with"), paragraphs: [
                Paragraph(body: localized("""
                    We do not sell your data, and the app contains no third-party advertising or tracking. We use \
                    two processors: Amazon Web Services, which hosts the service, and Apple, which delivers push \
                    notifications and provides the app's maps — the map screens load Apple Maps, and when you set \
                    an event's place, the place name you type is sent from your device to Apple's Maps service to \
                    find it. What you post is visible to other users according to where you post it: a public group \
                    or event is visible to anyone, a private group only to its members.
                    """))
            ])
        }

        static var rights: Section {
            Section(title: localized("Your rights"), paragraphs: [
                Paragraph(body: localized("""
                    You can ask for a copy of your data, have mistakes corrected (your display name and "about you" \
                    text you can edit in the app yourself), have your data erased (the in-app deletion above starts \
                    at once; a request by email is handled within 30 days), restrict or object to processing, and \
                    take your data elsewhere. Write to support@iskra.red. You also have the right to complain to \
                    your data protection authority.
                    """))
            ])
        }

        static var changes: Section {
            Section(title: Legal.changesTitle, paragraphs: [
                Paragraph(body: localized("""
                    When this policy changes, we update it and the date at its top. Continuing to use iskra after \
                    a change constitutes acceptance of the updated policy.
                    """))
            ])
        }
    }
}
