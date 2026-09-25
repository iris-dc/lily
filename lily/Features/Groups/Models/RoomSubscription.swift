import Foundation

/// One chat room to listen to: the group and the epoch its channel currently carries.
nonisolated struct RoomSubscription: Hashable, Sendable {
    let groupID: String
    let epoch: Int

    init(groupID: String, epoch: Int) {
        self.groupID = groupID
        self.epoch = epoch
    }

    init(group: SportGroup) {
        self.init(groupID: group.id, epoch: group.channelEpoch)
    }
}
