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


import WireTesting
@testable import WireMessageStrategy


class TeamDownloadRequestStrategyTests: MessagingTestBase {

    var sut: TeamDownloadRequestStrategy!
    var mockApplicationStatus : MockApplicationStatus!

    override func setUp() {
        super.setUp()
        mockApplicationStatus = MockApplicationStatus()
        sut = TeamDownloadRequestStrategy(withManagedObjectContext: syncMOC, applicationStatus: mockApplicationStatus)
    }

    override func tearDown() {
        mockApplicationStatus = nil
        sut = nil
        super.tearDown()
    }

    func testThatItDoesNotGenerateARequestInitially() {
        XCTAssertNil(sut.nextRequest())
    }

    func testThatItDoesNotCreateARequestIfThereIsNoTeamNeedingToBeUpdated() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = .create()
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing

            // when
            team.needsToBeUpdatedFromBackend = false
            self.boostrapChangeTrackers(with: team)

            // then
            XCTAssertNil(self.sut.nextRequest())
        }
    }

    func testThatItCreatesAReuqestForATeamThatNeedsToBeUpdatedFromTheBackend() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = .create()
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing

            // when
            team.needsToBeUpdatedFromBackend = true
            self.boostrapChangeTrackers(with: team)

            // then
            guard let request = self.sut.nextRequest() else { return XCTFail("No request generated") }
            XCTAssertEqual(request.method, .methodGET)
            XCTAssertEqual(request.path, "/teams/\(team.remoteIdentifier!.transportString())")
        }
    }

    func testThatItDoesNotCreateARequestDuringSync() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = .create()
            self.mockApplicationStatus.mockSynchronizationState = .synchronizing

            // when
            team.needsToBeUpdatedFromBackend = true
            self.boostrapChangeTrackers(with: team)

            // then
            XCTAssertNil(self.sut.nextRequest())
        }
    }


    func testThatItUpdatesTheTeamWithTheResponse() {
        var team: Team!
        let member1UserId = UUID.create()
        let member2UserId = UUID.create()

        syncMOC.performGroupedBlock {
            // given
            team = Team.insertNewObject(in: self.syncMOC)
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
            team.remoteIdentifier = .create()


            team.needsToBeUpdatedFromBackend = true
            self.boostrapChangeTrackers(with: team)
            guard let request = self.sut.nextRequest() else { return XCTFail("No request generated") }

            // when
            let payload: [String: Any] = [
                "id": team.remoteIdentifier!.transportString(),
                "members": [
                    ["id": member1UserId.transportString(), "permissions": ["CreateConversation", "DeleteConversation"]],
                    ["id": member2UserId.transportString(), "permissions": ["Admin"]]
                ]
            ]

            let response = ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil)

            // when
            request.complete(with: response)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.2))

        syncMOC.performGroupedBlockAndWait {
            // then
            XCTAssertFalse(team.needsToBeUpdatedFromBackend)

            let users = team.members.flatMap { $0.user }
            XCTAssertEqual(users.count, 2)
            users.forEach {
                if $0.remoteIdentifier == member1UserId {
                    XCTAssertEqual($0.permissions(in: team), [.createConversation, .deleteConversation])
                } else {
                    XCTAssertEqual($0.permissions(in: team), .admin)
                }
            }
            XCTAssertEqual(Set(users.map { $0.remoteIdentifier! }), [member1UserId, member2UserId])
        }
    }

    func testThatItCreatesNoNewRequestAfterReceivingAResponse() {
        var team: Team!

        syncMOC.performGroupedBlock {
            // given
            team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = .create()
            team.needsToBeUpdatedFromBackend = true
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
            self.boostrapChangeTrackers(with: team)

            guard let request = self.sut.nextRequest() else { return XCTFail("No request generated") }

            // when
            let payload: [String: Any] = ["id": team.remoteIdentifier!.transportString(), "members": []]
            let response = ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil)
            request.complete(with: response)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.2))

        syncMOC.performGroupedBlockAndWait {
            // then
            self.boostrapChangeTrackers(with: team)
            XCTAssertNil(self.sut.nextRequestIfAllowed())
        }
    }

    // MARK: - Helper

    private func boostrapChangeTrackers(with objects: ZMManagedObject...) {
        sut.contextChangeTrackers.forEach {
            $0.objectsDidChange(Set(objects))
        }

    }

}
