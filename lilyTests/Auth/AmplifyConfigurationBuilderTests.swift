import Foundation
import Testing
@testable import lily

struct AmplifyConfigurationBuilderTests {
    private func plugin(userPoolId: String = AppConfig.Cognito.userPoolId,
                        appClientId: String = AppConfig.Cognito.appClientId,
                        region: String = AppConfig.Cognito.region) throws -> [String: Any] {
        let data = try AmplifyConfigurationBuilder.cognitoPluginJSON(userPoolId: userPoolId,
                                                                     appClientId: appClientId,
                                                                     region: region)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The keys are the plugin's own (`ConfigurationHelper.parseUserPoolData`), so a typo here would be a silent misconfiguration.
    @Test func poolIdClientIdAndRegionSitUnderCognitoUserPoolDefault() throws {
        let pool = try #require(plugin()["CognitoUserPool"] as? [String: [String: String]])
        #expect(pool["Default"] == ["PoolId": "eu-central-1_JmfE31ODT",
                                    "AppClientId": "54dul3essertek166u2st78s4a",
                                    "Region": "eu-central-1"])
    }

    @Test func authenticationFlowIsSRP() throws {
        let auth = try #require(plugin()["Auth"] as? [String: [String: String]])
        #expect(auth["Default"]?["authenticationFlowType"] == "USER_SRP_AUTH")
    }

    @Test func takesTheIdsItIsGiven() throws {
        let given = try plugin(userPoolId: "p", appClientId: "c", region: "r")
        let pool = try #require(given["CognitoUserPool"] as? [String: [String: String]])
        #expect(pool["Default"] == ["PoolId": "p", "AppClientId": "c", "Region": "r"])
    }

    @Test func pluginKeyIsTheCognitoPluginsOwn() {
        #expect(AmplifyConfigurationBuilder.pluginKey == "awsCognitoAuthPlugin")
    }
}
