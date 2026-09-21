import Testing
@testable import lily

struct LaunchArgumentsTests {
    private let flag = AppConfig.LaunchArguments.apiBaseURL
    private let url = "http://mac.local:8080"

    @Test func valueIsTheArgumentAfterTheFlag() {
        let arguments = [AppConfig.LaunchArguments.mockLocation, flag, url, AppConfig.LaunchArguments.mockEvents]
        #expect(AppConfig.LaunchArguments.value(following: flag, in: arguments) == url)
    }

    @Test func missingFlagHasNoValue() {
        #expect(AppConfig.LaunchArguments.value(following: flag, in: [AppConfig.LaunchArguments.mockEvents, url]) == nil)
    }

    @Test func flagFollowedByAnotherFlagHasNoValue() {
        let arguments = [flag, AppConfig.LaunchArguments.mockEvents]
        #expect(AppConfig.LaunchArguments.value(following: flag, in: arguments) == nil)
    }

    @Test func flagAsLastArgumentHasNoValue() {
        let arguments = [AppConfig.LaunchArguments.mockEvents, flag]
        #expect(AppConfig.LaunchArguments.value(following: flag, in: arguments) == nil)
    }
}
