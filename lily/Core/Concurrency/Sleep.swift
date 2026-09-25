import Foundation

/// A pause a timer or a debounce waits on. Injected so tests hold and release it instead of waiting on a clock.
typealias Sleep = @Sendable (Duration) async throws -> Void

/// The pause production code takes: `Task.sleep`.
nonisolated let systemSleep: Sleep = { try await Task.sleep(for: $0) }
