import Foundation

/// Discover: the debounced search, the type filter and cursor paging. Every stored property lives in the main file.
extension GroupListViewModel {
    /// Discover has answered and nothing matched.
    var isDiscoverEmpty: Bool { scope == .discover && hasSearched && discovered.isEmpty && !isLoadingDiscover }

    var canLoadMore: Bool { nextCursor != nil && !isLoadingMore && !isLoadingDiscover }

    /// The name prefix sent to the backend: trimmed, capped at what it accepts, `nil` when nothing was typed.
    var effectiveQuery: String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(AppConfig.Groups.queryMaxLength))
    }

    /// Replaces the pages with the first one for the current query and type. A newer search started meanwhile wins:
    /// its generation differs, so this answer is dropped.
    func search() async {
        guard scope == .discover else { return }
        searchGeneration += 1
        let generation = searchGeneration
        isLoadingDiscover = true
        defer { if generation == searchGeneration { isLoadingDiscover = false } }
        do {
            let page = try await repository.groups(in: discoverScope, cursor: nil)
            guard generation == searchGeneration else { return }
            discovered = page.items
            nextCursor = page.nextCursor
            hasSearched = true
            searchedUserID = identity.currentUserID
            recordSearch(resultCount: page.items.count)
        } catch {
            guard !AppError.isCancellation(error), generation == searchGeneration else { return }
            logger.error(.groups, "Discover failed: \(error)")
            errorCenter.report(error)
        }
    }

    /// The next page, appended without repeating a group two pages both carry.
    func loadMore() async {
        guard let cursor = nextCursor, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let generation = searchGeneration
        do {
            let page = try await repository.groups(in: discoverScope, cursor: cursor)
            guard generation == searchGeneration else { return }
            let known = Set(discovered.map(\.id))
            discovered += page.items.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
            logger.debug(.groups, "Discover page appended: \(page.items.count) groups")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Discover paging failed: \(error)")
            errorCenter.report(error)
        }
    }

    /// Starts a search after the debounce (typing) or at once (a filter change), cancelling the one pending.
    func restartSearch(debounced: Bool) {
        guard scope == .discover else { return }
        cancel()
        searchTask = Task { [weak self, sleep] in
            if debounced {
                do { try await sleep(AppConfig.Groups.searchDebounce) } catch { return }
            }
            await self?.search()
        }
    }

    private var discoverScope: GroupScope {
        .discover(query: effectiveQuery, type: typeFilter)
    }

    /// Ids and flags only: whether something was typed and how many groups matched, never the text.
    private func recordSearch(resultCount: Int) {
        let hasQuery = effectiveQuery != nil
        recorder.record(.groupSearchPerformed(hasQuery: hasQuery, resultCount: resultCount, at: now()))
        logger.info(.groups, "Discover loaded \(resultCount) groups (query: \(hasQuery), type: \(typeFilter?.rawValue ?? "any"))")
    }
}
