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


class TeamDownloadRequestStrategy_EventsTests: MessagingTestBase {

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

    // MARK: - Team Create
    // The team.create update event is only sent to the creator of the team

    func testThatItCreatesALocalTeamWhenReceivingTeamCreateUpdateEvent() {
        // given
        let teamId = UUID.create()
        let payload: [String: Any] = [
            "type": "team.create",
            "team": teamId.transportString(),
            "time": "",
            "data": NSNull()
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        guard let team = Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil) else { return XCTFail("No team created") }
        XCTAssertTrue(team.needsToBeUpdatedFromBackend)
    }

    func testThatItSetsNeedsToBeUpdatedFromBackendForExistingTeamWhenReceivingTeamCreateUpdateEvent() {
        // given
        let teamId = UUID.create()

        syncMOC.performGroupedBlock {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        let payload: [String: Any] = [
            "type": "team.create",
            "team": teamId.transportString(),
            "time": "",
            "data": NSNull()
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        guard let team = Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil) else { return XCTFail("No team created") }
        XCTAssertTrue(team.needsToBeUpdatedFromBackend)
    }

    // MARK: - Team Delete 

    func testThatItDeletesAnExistingTeamWhenReceivingATeamDeleteUpdateEvent() {
        // given
        let teamId = UUID.create()

        syncMOC.performGroupedBlock {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        XCTAssertNotNil(Team.fetch(withRemoteIdentifier: teamId, in: uiMOC))

        let payload: [String: Any] = [
            "type": "team.delete",
            "team": teamId.transportString(),
            "time": "",
            "data": NSNull()
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        XCTAssertNil(Team.fetch(withRemoteIdentifier: teamId, in: uiMOC))
    }

    // MARK: - Team Update

    func testThatItUpdatesATeamsNameWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let dataPayload = ["name": "Wire GmbH"]

        // when
        guard let team = assertThatItUpdatesTeamsProperties(with: dataPayload) else { return XCTFail("No Team") }

        // then
        XCTAssertEqual(team.name, "Wire GmbH")
    }

    func testThatItUpdatesATeamsIconWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let newAssetId = UUID.create().transportString()
        let dataPayload = ["icon": newAssetId]

        // when
        guard let team = assertThatItUpdatesTeamsProperties(with: dataPayload) else { return XCTFail("No Team") }

        // then
        XCTAssertEqual(team.pictureAssetId, newAssetId)
    }

    func testThatItUpdatesATeamsIconKeyWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let newAssetKey = UUID.create().transportString()
        let dataPayload = ["icon_key": newAssetKey]

        // when
        guard let team = assertThatItUpdatesTeamsProperties(with: dataPayload) else { return XCTFail("No Team") }

        // then
        XCTAssertEqual(team.pictureAssetKey, newAssetKey)
    }

    func assertThatItUpdatesTeamsProperties(
        with dataPayload: [String: Any]?,
        preExistingTeam: Bool = true,
        file: StaticString = #file,
        line: UInt = #line) -> Team? {

        // given
        let teamId = UUID.create()

        if preExistingTeam {
            syncMOC.performGroupedBlock {
                let team = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)!
                team.name = "Some Team"
                team.remoteIdentifier = teamId
                team.pictureAssetId = UUID.create().transportString()
                team.pictureAssetKey = UUID.create().transportString()
                XCTAssert(self.syncMOC.saveOrRollback())
            }

            XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1), file: file, line: line)
            XCTAssertNotNil(Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil))
        }

        let payload: [String: Any] = [
            "type": "team.update",
            "team": teamId.transportString(),
            "time": "",
            "data": dataPayload ?? NSNull()
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        return Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil)
    }

    // FIXME: Is this the desired behaviour or should we just create the team?
    // In theory, this should never happen as we should receive a team.create or team.member-join event first.
    func testThatItDoesNotCreateATeamIfItDoesNotAlreadyExistWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let dataPayload = ["name": "Wire GmbH"]

        // then
        XCTAssertNil(assertThatItUpdatesTeamsProperties(with: dataPayload, preExistingTeam: false))
    }

    // MARK: - Team Member-Join

    func testThatItAddsANewTeamMemberAndUserWhenReceivingATeamMemberJoinUpdateEventExistingTeam() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlock {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)!
            XCTAssert(self.syncMOC.saveOrRollback())
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": "",
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: uiMOC) else { return XCTFail("No user") }
        guard let team = Team.fetch(withRemoteIdentifier: teamId, in: uiMOC) else { return XCTFail("No team") }
        guard let member = user.membership(in: team) else { return XCTFail("No member") }

        XCTAssertTrue(user.needsToBeUpdatedFromBackend)
        XCTAssertFalse(team.needsToBeUpdatedFromBackend)
        XCTAssertTrue(team.needsToRedownloadMembers)
        XCTAssertEqual(member.team, team)
    }

    func testThatItAddsANewTeamMemberToAnExistingUserWhenReceivingATeamMemberJoinUpdateEventExistingTeam() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlockAndWait {
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": "",
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No user") }
            guard let team = Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) else { return XCTFail("No team") }
            guard let member = user.membership(in: team) else { return XCTFail("No member") }

            XCTAssertTrue(user.needsToBeUpdatedFromBackend)
            XCTAssertFalse(team.needsToBeUpdatedFromBackend)
            XCTAssertTrue(team.needsToRedownloadMembers)
            XCTAssertEqual(member.team, team)
        }
    }

    func testThatItCreatesATeamWhenReceivingAMemberJoinEventForTheSelfUserWithoutExistingTeam() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": "",
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No user") }
            guard let team = Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) else { return XCTFail("No team") }
            guard let member = user.membership(in: team) else { return XCTFail("No member") }

            XCTAssertTrue(user.needsToBeUpdatedFromBackend)
            XCTAssertTrue(team.needsToBeUpdatedFromBackend)
            XCTAssertFalse(team.needsToRedownloadMembers)
            XCTAssertEqual(member.team, team)
        }
    }

    // MARK: - Team Member-Leave

    func testThatItDeletesAMemberWhenReceivingATeamMemberLeaveUpdateEventForAnotherUser() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlock {
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            XCTAssertNotNil(member)
            XCTAssertEqual(user.membership(in: team), member)
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))

        let payload: [String: Any] = [
            "type": "team.member-leave",
            "team": teamId.transportString(),
            "time": "",
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNotNil(ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC))

            // users won't be deleted as we might be in other (non-team) conversations with them
            guard let team = Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) else { return XCTFail("No team") }
            XCTAssertEqual(team.members, [])
        }
    }

    func testThatItDeletesTheSelfMemberWhenReceivingATeamMemberLeaveUpdateEventForSelfUser() {
        let teamId = UUID.create()
        var userId: UUID!

        syncMOC.performGroupedBlockAndWait {
            // given
            let user = ZMUser.selfUser(in: self.syncMOC)
            userId = user.remoteIdentifier!
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            XCTAssertNotNil(member)
            XCTAssertEqual(user.membership(in: team), member)
        }

        // when
        let payload: [String: Any] = [
            "type": "team.member-leave",
            "team": teamId.transportString(),
            "time": "",
            "data": ["user" : userId.transportString()]
        ]
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNotNil(ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC))
            XCTAssertNil(Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC))
        }
    }

    func testThatItOnlyDeletesTheMembershipInTheTeamSpecifiedIfTheMemberIsPartOfMultipleTeams() {
        // given
        let team1Id = UUID.create()
        let team2Id = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlock {
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let team1 = Team.insertNewObject(in: self.syncMOC)
            team1.remoteIdentifier = team1Id
            let team2 = Team.insertNewObject(in: self.syncMOC)
            team2.remoteIdentifier = team2Id
            let member1 = Member.getOrCreateMember(for: user, in: team1, context: self.syncMOC)
            let member2 = Member.getOrCreateMember(for: user, in: team2, context: self.syncMOC)
            XCTAssertEqual(user.membership(in: team1), member1)
            XCTAssertEqual(user.membership(in: team2), member2)
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))

        let payload: [String: Any] = [
            "type": "team.member-leave",
            "team": team1Id.transportString(),
            "time": "",
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No User") }
            XCTAssertEqual(user.memberships.map { $0.team!.remoteIdentifier! }, [team2Id])
            guard let team = Team.fetch(withRemoteIdentifier: team1Id, in: self.syncMOC) else { return XCTFail("No team") }
            XCTAssertEqual(team.members, [])
        }
    }

    // MARK: - Team Conversation-Create

    func testThatItCreatesANewTeamConversationWhenReceivingATeamConversationCreateUpdateEvent() {
        // given
        let conversationId = UUID.create()
        let teamId = UUID.create()

        syncMOC.performGroupedBlockAndWait {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
        }

        let payload: [String: Any] = [
            "type": "team.conversation-create",
            "team": teamId.transportString(),
            "time": "",
            "data": ["conv": conversationId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let conversation = ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC) else { return XCTFail("No conversation") }
            XCTAssertNotNil(conversation.team)
            XCTAssertEqual(conversation.team?.remoteIdentifier, teamId)
            XCTAssertTrue(conversation.needsToBeUpdatedFromBackend)
        }
    }

    // FIXME: Is this the desired behaviour or should we just create the team?
    // In theory, this should never happen as we should receive a team.create or team.member-join event first.
    func testThatItDoesNotCreateANewTeamConversationWhenReceivingATeamConversationCreateEventWithoutLocalTeam() {
        // given
        let conversationId = UUID.create()
        let teamId = UUID.create()

        let payload: [String: Any] = [
            "type": "team.conversation-create",
            "team": teamId.transportString(),
            "time": "",
            "data": ["conv": conversationId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNil(ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC))
            XCTAssertNil(Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC))
        }
    }

    // MARK: - Team Conversation-Delete (Member)

    func testThatItDeletesALocalTeamConversationInWhichSelfIsAMember() {
        // given
        let conversationId = UUID.create()
        let teamId = UUID.create()

        syncMOC.performGroupedBlockAndWait {
            let team = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.remoteIdentifier = conversationId
            conversation.conversationType = .group
            conversation.team = team

            XCTAssertNotNil(ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC))
            XCTAssertNotNil(Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC))
        }

        let payload: [String: Any] = [
            "type": "team.conversation-delete",
            "team": teamId.transportString(),
            "time": "",
            "data": ["conv": conversationId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNil(ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC))
            XCTAssertNotNil(Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC))
        }
    }

    func testThatItDoesNotDeleteALocalConversationIfTheTeamDoesNotMatchTheTeamInTheEventPayload() {
        // given
        let conversationId = UUID.create()
        let teamId = UUID.create()
        let otherTeamId = UUID.create()

        syncMOC.performGroupedBlockAndWait {
            let team = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
            _ = Team.fetchOrCreate(with: otherTeamId, create: true, in: self.syncMOC, created: nil)
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.remoteIdentifier = conversationId
            conversation.conversationType = .group
            conversation.team = team

            XCTAssertNotNil(ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC))
            XCTAssertNotNil(Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC))
        }

        let payload: [String: Any] = [
            "type": "team.conversation-delete",
            "team": otherTeamId.transportString(),
            "time": "",
            "data": ["conv": conversationId.transportString()]
        ]

        // when
        performIgnoringZMLogError {
            self.processEvent(fromPayload: payload)
        }

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let conversation = ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC) else { return XCTFail("No conversation") }
            XCTAssertEqual(conversation.team?.remoteIdentifier, teamId)
            XCTAssertNotNil(Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC))
        }
    }

    // MARK: - Conversation-Delete (Guest)

    func disabled_testThatItDeletesALocalTeamConversationInWhichSelfIsAGuest() {
        // given
        let conversationId = UUID.create()
        let payload: [String: Any] = [
            "type": "conversation-delete",
            "time": "",
            "data": ["conv": conversationId.transportString()]
        ]

        syncMOC.performGroupedBlockAndWait {
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.remoteIdentifier = conversationId
            conversation.conversationType = .group
            XCTAssertNotNil(ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC))
        }

        // when
        processEvent(fromPayload: payload)

        XCTFail("Implement and test behaviour when self is a guest in a team conversation which gets deleted.")
    }

    // MARK: - Helper

    private func processEvent(fromPayload eventPayload: [String: Any], file: StaticString = #file, line: UInt = #line) {
        guard let event = ZMUpdateEvent(fromEventStreamPayload: eventPayload as ZMTransportData, uuid: nil) else {
            return XCTFail("Unable to create update event from payload", file: file, line: line)
        }

        // when
        syncMOC.performGroupedBlock {
            self.sut.processEvents([event], liveEvents: false, prefetchResult: nil)
            XCTAssert(self.syncMOC.saveOrRollback(), file: file, line: line)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5), file: file, line: line)
    }

}
