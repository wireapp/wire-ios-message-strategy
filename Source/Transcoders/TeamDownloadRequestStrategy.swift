//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//


fileprivate extension Team {

    static var predicateForObjectsNeedingToBeUpdated: NSPredicate = {
        NSPredicate(format: "%K == YES AND %K != NULL", #keyPath(Team.needsToBeUpdatedFromBackend), #keyPath(Team.remoteIdentifier))
    }()

    func update(with response: ZMTransportResponse) {
        guard let membersPayload = response.payload?.asDictionary()?["members"] as? [[String: Any]] else { return }
        membersPayload.forEach {
            if let id = ($0["id"] as? String).flatMap(UUID.init), let user = ZMUser(remoteID: id, createIfNeeded: true, in: managedObjectContext!) {
                let member = Member.getOrCreateMember(for: user, in: self, context: managedObjectContext!)
                if let permissions = $0["permissions"] as? [String] {
                    member.permissions = Permissions(payload: permissions)
                }
            }
        }
    }

}


final private class TeamDownloadRequestFactory {

    static var teamPath: String {
        return "/teams"
    }

    static func getRequest(for identifier: UUID) -> ZMTransportRequest {
        return ZMTransportRequest(getFromPath: teamPath + "/\(identifier.transportString())")
    }

}


public final class TeamDownloadRequestStrategy: AbstractRequestStrategy, ZMContextChangeTrackerSource, ZMRequestGeneratorSource {

    fileprivate var downstreamSync: ZMDownstreamObjectSync!

    public override init(withManagedObjectContext managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus) {
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        configuration = .allowsRequestsDuringEventProcessing
        downstreamSync = ZMDownstreamObjectSync(
            transcoder: self,
            entityName: Team.entityName(),
            predicateForObjectsToDownload: Team.predicateForObjectsNeedingToBeUpdated,
            filter: nil,
            managedObjectContext: managedObjectContext
        )
    }

    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        return downstreamSync.nextRequest()
    }

    public var contextChangeTrackers: [ZMContextChangeTracker] {
        return [downstreamSync]
    }

    public var requestGenerators: [ZMRequestGenerator] {
        return [downstreamSync]
    }

}


extension TeamDownloadRequestStrategy: ZMDownstreamTranscoder {

    public func request(forFetching object: ZMManagedObject!, downstreamSync: ZMObjectSync!) -> ZMTransportRequest! {
        guard downstreamSync as? ZMDownstreamObjectSync == self.downstreamSync, let team = object as? Team else { return nil }
        return team.remoteIdentifier.map(TeamDownloadRequestFactory.getRequest)
    }

    public func update(_ object: ZMManagedObject!, with response: ZMTransportResponse!, downstreamSync: ZMObjectSync!) {
        guard downstreamSync as? ZMDownstreamObjectSync == self.downstreamSync, let team = object as? Team else { return }
        team.needsToBeUpdatedFromBackend = false
        team.update(with: response)
    }

    public func delete(_ object: ZMManagedObject!, downstreamSync: ZMObjectSync!) {
        // no-op
    }
}
