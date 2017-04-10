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

import Foundation
import XCTest
import WireMessageStrategy
import WireDataModel


class SystemMessageEventsConsumerTests: MessagingTestBase {
    
    var sut: SystemMessageEventsConsumer!
    var localNotificationDispatcher: MockPushMessageHandler!
    var conversation: ZMConversation!
    var user: ZMUser!
    
    override func setUp() {
        super.setUp()
        
        self.syncMOC.performGroupedBlockAndWait {
            self.localNotificationDispatcher = MockPushMessageHandler()
            self.sut = SystemMessageEventsConsumer(moc: self.syncMOC, localNotificationDispatcher: self.localNotificationDispatcher)
            self.conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            self.conversation.remoteIdentifier = UUID.create()
            self.conversation.conversationType = .group
            self.conversation.lastServerTimeStamp = Date(timeIntervalSince1970: 123124)
            self.conversation.lastReadServerTimeStamp = self.conversation.lastServerTimeStamp
            self.user = ZMUser.insertNewObject(in: self.syncMOC)
            self.user.remoteIdentifier = UUID.create()

            self.syncMOC.saveOrRollback()
        }
    }
    
    override func tearDown() {
        self.sut = nil
        self.localNotificationDispatcher = nil
        self.conversation = nil
        super.tearDown()
    }
    
    func testThatItCreatesAndNotifiesSystemMessagesFromAMemberJoin() {
        
        self.syncMOC.performAndWait { 
            
            // GIVEN
            let payload = [
                "from": self.user.remoteIdentifier!.transportString(),
                "conversation": self.conversation.remoteIdentifier!.transportString(),
                "time": NSDate().transportString(),
                "data": [
                    "user_ids": [self.user.remoteIdentifier!.transportString()]
                ],
                "type": "conversation.member-join"
            ] as [String: Any]
            let event = ZMUpdateEvent(fromEventStreamPayload: payload as ZMTransportData, uuid: nil)!
            
            // WHEN
            self.sut.processEvents([event], liveEvents: true, prefetchResult: nil)
            
            // THEN
            guard let message = self.conversation.messages.lastObject as? ZMSystemMessage else {
                XCTFail()
                return
            }
            XCTAssertEqual(message.systemMessageType, .participantsAdded)
            XCTAssertEqual(self.localNotificationDispatcher.processedMessages.last, message)
        }
    }
    
    func testThatItCreatesAndNotifiesSystemMessagesFromAMemberRemove() {
        
        self.syncMOC.performAndWait {
            
            // GIVEN
            let payload = [
                "from": self.user.remoteIdentifier!.transportString(),
                "conversation": self.conversation.remoteIdentifier!.transportString(),
                "time": NSDate().transportString(),
                "data": [
                    "user_ids": [self.user.remoteIdentifier!.transportString()]
                ],
                "type": "conversation.member-leave"
                ] as [String: Any]
            let event = ZMUpdateEvent(fromEventStreamPayload: payload as ZMTransportData, uuid: nil)!
            
            // WHEN
            self.sut.processEvents([event], liveEvents: true, prefetchResult: nil)
            
            // THEN
            guard let message = self.conversation.messages.lastObject as? ZMSystemMessage else {
                XCTFail()
                return
            }
            XCTAssertEqual(message.systemMessageType, .participantsRemoved)
            XCTAssertEqual(self.localNotificationDispatcher.processedMessages.last, message)
        }
    }
    
    func testThatItCreatesAndNotifiesSystemMessagesFromConversationRename() {
        
        self.syncMOC.performAndWait {
            
            // GIVEN
            let payload = [
                "from": self.user.remoteIdentifier!.transportString(),
                "conversation": self.conversation.remoteIdentifier!.transportString(),
                "time": NSDate().transportString(),
                "data": [
                    "name": "foobar"
                ],
                "type": "conversation.rename"
                ] as [String: Any]
            let event = ZMUpdateEvent(fromEventStreamPayload: payload as ZMTransportData, uuid: nil)!
            
            // WHEN
            self.sut.processEvents([event], liveEvents: true, prefetchResult: nil)
            
            // THEN
            guard let message = self.conversation.messages.lastObject as? ZMSystemMessage else {
                XCTFail()
                return
            }
            XCTAssertEqual(message.systemMessageType, .conversationNameChanged)
            XCTAssertEqual(self.localNotificationDispatcher.processedMessages.last, message)
        }
    }
    
    func testThatItSetsHasUnreadMissedCallWhenReceivingAMissedCallEvent() {
        
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let event = self.missedEvent(
                from: self.user,
                time: self.conversation.lastReadServerTimeStamp!.addingTimeInterval(1200),
                conversation: self.conversation
            )
            
            // WHEN
            self.sut.processEvents([event], liveEvents: false, prefetchResult: nil)
            
            // THEN
            guard let message = self.conversation.messages.lastObject as? ZMSystemMessage else {
                XCTFail()
                return
            }
            XCTAssertEqual(message.systemMessageType, .missedCall)
            XCTAssertEqual(self.localNotificationDispatcher.processedMessages.last, message)
            XCTAssertEqual(self.conversation.conversationListIndicator, .missedCall)
            XCTAssertTrue(self.conversation.hasUnreadMissedCall)
            XCTAssertFalse(self.conversation.keysThatHaveLocalModifications.contains(ZMConversationHasUnreadMissedCallKey))
        }
    }

    // TODO: This test can be removed once group call are on v3 as well.
    func testThatItCollapsesMultipleSuccessiveMissedCallSystemMessages() {
        syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let beforeCount = self.conversation.messages.count

            let firstEvent = self.missedEvent(
                from: self.user,
                time: self.conversation.lastReadServerTimeStamp!.addingTimeInterval(100),
                conversation: self.conversation
            )

            let secondEvent = self.missedEvent(
                from: self.user,
                time: firstEvent.timeStamp()!.addingTimeInterval(100),
                conversation: self.conversation
            )

            // WHEN
            self.sut.processEvents([firstEvent, secondEvent], liveEvents: false, prefetchResult: nil)

            // THEN
            XCTAssertEqual(self.conversation.messages.count - beforeCount, 1)
            guard let message = self.conversation.messages.lastObject as? ZMSystemMessage else { return XCTFail() }
            XCTAssertEqual(message.systemMessageType, .missedCall)

            guard let childMessage = message.childMessages.first as? ZMSystemMessageData else { return XCTFail() }
            XCTAssertEqual(childMessage.systemMessageType, .missedCall)
        }
    }


    // MARK: – Helper

    private func missedEvent(from user: ZMUser, time: Date, conversation: ZMConversation) -> ZMUpdateEvent {
        let payload = [
            "from": user.remoteIdentifier!.transportString(),
            "conversation": conversation.remoteIdentifier!.transportString(),
            "time": time.transportString(),
            "data": ["reason": "missed"],
            "type": "conversation.voice-channel-deactivate"
        ] as ZMTransportData

        return ZMUpdateEvent(fromEventStreamPayload: payload, uuid: nil)!
    }
}
