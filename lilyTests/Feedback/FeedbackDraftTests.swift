import Foundation
import Testing
@testable import lily

/// The contact form's validation and the one place a draft becomes the request body.
struct FeedbackDraftTests {
    @Test func anEmptyMessageIsTheOnlyIssueOfAFreshDraftAndHasNoHint() {
        let draft = FeedbackDraft()
        #expect(draft.kind == .feedback && draft.replyEmail.isEmpty)
        #expect(draft.issues == [.messageMissing] && !draft.isValid)
        #expect(draft.hint(for: .message) == nil && draft.hint(for: .replyEmail) == nil)
    }

    @Test func theMessageIsMeasuredAsTheBackendMeasuresIt() {
        var draft = FeedbackDraft(message: String(repeating: "x", count: AppConfig.Feedback.messageMaxLength))
        #expect(draft.isValid)
        draft.message += "x"
        #expect(draft.issues == [.messageTooLong])
        // The number is formatted in the test host's locale ("2.000" on a German simulator), so compare the copy itself.
        #expect(draft.hint(for: .message) == AppBranding.Feedback.tooLong(limit: AppConfig.Feedback.messageMaxLength))
        #expect(draft.hint(for: .message)?.hasPrefix("Keep it under") == true)

        draft.message = String(repeating: "🏓", count: AppConfig.Feedback.messageMaxLength / 2 + 1)
        #expect(draft.issues == [.messageTooLong], "an emoji counts two, as Java's String.length() does")
    }

    @Test func aBlankEmailIsFineAndAMalformedOrOverlongOneIsNot() {
        var draft = FeedbackDraft(message: "Hello", replyEmail: "   ")
        #expect(draft.isValid)
        draft.replyEmail = "jane@"
        #expect(draft.issues == [.emailInvalid] && draft.hint(for: .replyEmail) == "That email doesn't look right")
        draft.replyEmail = String(repeating: "j", count: AppConfig.Feedback.replyEmailMaxLength) + "@example.com"
        #expect(draft.issues == [.emailTooLong])
        #expect(draft.hint(for: .replyEmail) == AppBranding.Feedback.tooLong(limit: AppConfig.Feedback.replyEmailMaxLength))
        draft.replyEmail = "jane@example.com"
        #expect(draft.isValid && draft.hint(for: .replyEmail) == nil)
    }

    @Test func issuesComeInFormOrder() {
        let draft = FeedbackDraft(message: "", replyEmail: "nope")
        #expect(draft.issues == [.messageMissing, .emailInvalid])
        #expect(draft.issues.map(\.field) == [.message, .replyEmail])
    }

    @Test func thePayloadTrimsTheWordsDropsABlankEmailAndCutsTheDetails() throws {
        let draft = FeedbackDraft(kind: .bug, message: "  It crashed.  ", replyEmail: " ")
        let long = FeedbackEnvironment(appVersion: String(repeating: "v", count: 100),
                                       osVersion: "iOS 26.0.1",
                                       device: "iPhone17,1",
                                       locale: "ru")
        let payload = draft.payload(in: long)

        #expect(payload.kind == .bug && payload.message == "It crashed." && payload.replyEmail == nil)
        #expect(payload.appVersion?.count == AppConfig.Feedback.detailMaxLength)
        #expect(payload.osVersion == "iOS 26.0.1" && payload.device == "iPhone17,1" && payload.locale == "ru")

        let data = try APIJSONCoding.makeEncoder().encode(payload)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json.keys.sorted() == ["appVersion", "device", "kind", "locale", "message", "osVersion"],
                "a blank email is left out, never sent as null")
        #expect(json["kind"] == "bug")
    }

    /// Key for key the body Laurel's strict-JSON test expects.
    @Test func aFullPayloadCarriesEveryKeyTheContractNames() throws {
        let draft = FeedbackDraft(kind: .contact, message: "Hi", replyEmail: "jane@example.com")
        let data = try APIJSONCoding.makeEncoder().encode(draft.payload(in: .fixture))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(json == ["kind": "contact", "message": "Hi", "replyEmail": "jane@example.com", "appVersion": "1.0 (42)",
                         "osVersion": "iOS 26.0.1", "device": "iPhone17,1", "locale": "en"])
    }

    @Test func theReceiptDecodesTheBackendsAnswer() throws {
        let json = Data(#"{"id":"01J9FEEDBACK00000000000001","createdAt":"2026-10-08T10:00:00Z"}"#.utf8)
        let receipt = try APIJSONCoding.makeDecoder().decode(FeedbackReceipt.self, from: json)
        #expect(receipt.id == "01J9FEEDBACK00000000000001")
        #expect(receipt.createdAt == Date(timeIntervalSince1970: 1_791_453_600))
    }

    @Test func theKindsAreTheWireNamesInSegmentOrder() {
        #expect(FeedbackKind.allCases == [.contact, .feedback, .bug])
        #expect(FeedbackKind.allCases.map(\.rawValue) == ["contact", "feedback", "bug"])
        #expect(FeedbackKind.allCases.map(\.displayName) == ["Question", "Feedback", "Bug"])
        #expect(FeedbackKind.bug.messagePlaceholder == "What happened, and what did you expect?")
    }
}

struct FeedbackEnvironmentTests {
    @Test func theOSVersionNamesThePatchOnlyWhenThereIsOne() {
        #expect(FeedbackEnvironment.osVersionText(.init(majorVersion: 26, minorVersion: 0, patchVersion: 0)) == "iOS 26.0")
        #expect(FeedbackEnvironment.osVersionText(.init(majorVersion: 26, minorVersion: 1, patchVersion: 2)) == "iOS 26.1.2")
    }

    @Test func theSummaryJoinsTheThreeDetails() {
        #expect(FeedbackEnvironment.fixture.summary == "1.0 (42) · iOS 26.0.1 · iPhone17,1")
    }

    @Test func theDeviceModelPrefersTheSimulatorsAndFallsBackToUname() {
        #expect(DeviceModel.identifier(environment: ["SIMULATOR_MODEL_IDENTIFIER": "iPhone17,1"]) == "iPhone17,1")
        #expect(!DeviceModel.identifier(environment: [:]).isEmpty)
        #expect(!DeviceModel.identifier(environment: ["SIMULATOR_MODEL_IDENTIFIER": ""]).isEmpty)
    }

    @Test func currentReadsTheVersionTheHeaderCarriesAndTheLanguage() {
        let environment = FeedbackEnvironment.current(appVersion: AppVersion(marketing: "1.0", build: "42"),
                                                      languageCode: "pl")
        #expect(environment.appVersion == "1.0 (42)" && environment.locale == "pl")
        #expect(environment.osVersion.hasPrefix("iOS ") && !environment.device.isEmpty)
    }
}
