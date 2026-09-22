import Foundation

/// The Amplify configuration Cognito needs, built from `AppConfig.Cognito` instead of a generated
/// `amplifyconfiguration.json`: nothing to keep in sync with rose's outputs by hand, nothing extra in the bundle.
/// The legacy shape, because it is the one that states the auth flow explicitly.
nonisolated enum AmplifyConfigurationBuilder {
    /// Key of the Cognito plugin inside Amplify's `auth.plugins`.
    static let pluginKey = "awsCognitoAuthPlugin"
    /// SRP: the password never leaves the device; the `lily-ios` client allows exactly this flow plus refresh.
    static let authenticationFlow = "USER_SRP_AUTH"

    /// The `awsCognitoAuthPlugin` object as JSON, the way the plugin parses it (`CognitoUserPool.Default` for the pool,
    /// `Auth.Default.authenticationFlowType` for the flow).
    static func cognitoPluginJSON(userPoolId: String = AppConfig.Cognito.userPoolId,
                                  appClientId: String = AppConfig.Cognito.appClientId,
                                  region: String = AppConfig.Cognito.region) throws -> Data {
        let plugin: [String: Any] = [
            "CognitoUserPool": ["Default": ["PoolId": userPoolId, "AppClientId": appClientId, "Region": region]],
            "Auth": ["Default": ["authenticationFlowType": authenticationFlow]],
        ]
        return try JSONSerialization.data(withJSONObject: plugin, options: [.sortedKeys])
    }
}
