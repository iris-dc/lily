import Foundation

/// Discover: the debounced search, the type filter and cursor paging. Every stored property lives in the main file.
extension GroupListViewModel {
    /// Discover has answered and nothing matched.
    var isDiscoverEmpty: Bool { scope == .discover && hasSearched && discovered.isEmpty && !isLoadingDiscover }

    var canLoadMore: Bool { nextCursor != nil && !isLoadingMore && !isLoadingDiscover }

    /// The name prefix sent to the backend: trimmed, capped at what it accepts (counted in UTF-16 units, as Laurel
    /// does), `nil` when nothing was typed.
    var effectiveQuery: String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.prefix(wireLength: AppConfig.Groups.queryMaxLength)
    }

    /// Replaces the pages with the first one for the current query and type. A newer search started meanwhile wins:
    /// its generation differs, so this answer is dropped. A position that arrived or moved while the request was out
    /// earns one search right away, so the page around the user replaces the answer without waiting for the next
    /// appearance; a failure or a cancellation never does, so a backend that is down is not asked in a loop.
    func search() async {
        guard scope == .discover else { return }
        searchGeneration += 1
        let generation = searchGeneration
        isLoadingDiscover = true
        let answered = await performSearch(near: discoverPosition, generation: generation)
        guard generation == searchGeneration else { return }
        isLoadingDiscover = false
        if answered, searchedPosition != discoverPosition {
            logger.debug(.cache, "Position changed while Discover searched; searching again")
            await search()
        }
    }

    /// One request and its bookkeeping; answers whether this generation's page was taken.
    private func performSearch(near position: Coordinate?, generation: Int) async -> Bool {
        do {
            let page = try await repository.groups(in: discoverScope, cursor: nil, near: position)
            guard generation == searchGeneration else { return false }
            discovered = page.items
            nextCursor = page.nextCursor
            hasSearched = true
            searchedUserID = identity.currentUserID
            searchedChangesVersion = store.changesVersion
            searchedPosition = position
            recordSearch(resultCount: page.items.count)
            return true
        } catch {
            guard !AppError.isCancellation(error), generation == searchGeneration else { return false }
            logger.error(.groups, "Discover failed: \(error)")
            if reportsSearchFailures { errorCenter.report(error) }
            return false
        }
    }

    /// The next page, appended without repeating a group two pages both carry; it asks as the first page did, so the
    /// cursor is read against the same order.
    func loadMore() async {
        guard let cursor = nextCursor, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let generation = searchGeneration
        do {
            let page = try await repository.groups(in: discoverScope, cursor: cursor, near: searchedPosition)
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

    /// What a browse sends: the user's position as the backend receives it. A name search is global and sends none.
    var discoverPosition: Coordinate? {
        effectiveQuery == nil ? userLocation?.coarse : nil
    }

    /// Ids and flags only: whether something was typed and how many groups matched, never the text.
    private func recordSearch(resultCount: Int) {
        let hasQuery = effectiveQuery != nil
        recorder.record(.groupSearchPerformed(hasQuery: hasQuery, resultCount: resultCount, at: now()))
        logger.info(.groups, "Discover loaded \(resultCount) groups (query: \(hasQuery), type: \(typeFilter?.rawValue ?? "any"))")
    }
}
