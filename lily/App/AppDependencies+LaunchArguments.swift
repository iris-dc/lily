import Foundation

/// The value-taking launch arguments that name a URL (`-api-base-url`, `-realtime-endpoint`): read here so the
/// composition root stays within its type-body limit.
extension AppDependencies {
    /// The `-api-base-url` value when it is a URL with a scheme and a host, otherwise `AppConfig.API.baseURL`.
    static func apiBaseURL(from arguments: [String], logger: any Logging) -> URL {
        guard let url = url(following: AppConfig.LaunchArguments.apiBaseURL, in: arguments, logger: logger) else {
            return AppConfig.API.baseURL
        }
        logger.info(.network, "API base URL overridden: \(url.absoluteString)")
        return url
    }

    /// A value flag's URL when it parses with a scheme and a host; a malformed value is ignored with a warning.
    static func url(following flag: String, in arguments: [String], logger: any Logging) -> URL? {
        guard let value = AppConfig.LaunchArguments.value(following: flag, in: arguments) else { return nil }
        guard let url = URL(string: value), url.scheme != nil, url.host() != nil else {
            logger.warning(.network, "Ignoring \(flag): not a URL with a scheme and a host")
            return nil
        }
        return url
    }
}
