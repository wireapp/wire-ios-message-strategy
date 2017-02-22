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

////
//
//
//@implementation ZMClientMessageTranscoderTests (Ephemeral)
//
//- (void)testThatItDoesNotObfuscatesEphemeralMessagesOnStart_SenderSelfUser_TimeNotPassed
//{
//    // given
//    ZMConversation *conversation = [self setupOneOnOneConversation];
//    conversation.messageDestructionTimeout = 10;
//    ZMMessage *message = (id)[conversation appendMessageWithText:@"foo"];
//    [message markAsSent];
//    XCTAssertTrue(message.isEphemeral);
//    XCTAssertFalse(message.isObfuscated);
//    XCTAssertNotNil(message.sender);
//    XCTAssertNotNil(message.destructionDate);
//    [self.syncMOC saveOrRollback];
//
//    // when
//    [self.sut tearDown];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self setupSUT];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    // then
//    XCTAssertFalse(message.isObfuscated);
//
//    // teardown
//    [self.syncMOC performGroupedBlockAndWait:^{
//        [self.syncMOC zm_teardownMessageObfuscationTimer];
//    }];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self.uiMOC performGroupedBlockAndWait:^{
//        [self.uiMOC zm_teardownMessageDeletionTimer];
//    }];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//}
//
//- (void)testThatItObfuscatesEphemeralMessagesOnStart_SenderSelfUser_TimePassed
//{
//    // given
//    ZMConversation *conversation = [self setupOneOnOneConversation];
//    conversation.messageDestructionTimeout = 1;
//    ZMMessage *message = (id)[conversation appendMessageWithText:@"foo"];
//    [message markAsSent];
//    XCTAssertTrue(message.isEphemeral);
//    XCTAssertFalse(message.isObfuscated);
//    XCTAssertNotNil(message.sender);
//    XCTAssertNotNil(message.destructionDate);
//    [self.syncMOC saveOrRollback];
//
//    // when
//    [self.sut tearDown];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self setupSUT];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self spinMainQueueWithTimeout:1.5];
//
//    // then
//    [self.uiMOC refreshAllObjects];
//    XCTAssertTrue(message.isObfuscated);
//    XCTAssertNotEqual(message.hiddenInConversation, conversation);
//    XCTAssertEqual(message.visibleInConversation, conversation);
//
//    // teardown
//    [self.syncMOC performGroupedBlockAndWait:^{
//        [self.syncMOC zm_teardownMessageObfuscationTimer];
//    }];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self.uiMOC performGroupedBlockAndWait:^{
//        [self.uiMOC zm_teardownMessageDeletionTimer];
//    }];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//}
//
//- (void)testThatItDeletesEphemeralMessagesOnStart_SenderOtherUser
//{
//    // given
//    self.uiMOC.zm_messageDeletionTimer.isTesting = YES;
//    ZMConversation *conversation = [self setupOneOnOneConversationInContext:self.uiMOC];
//    conversation.messageDestructionTimeout = 1.0;
//    ZMMessage *message = (id)[conversation appendMessageWithText:@"foo"];
//    message.sender = conversation.connectedUser;
//    [message startSelfDestructionIfNeeded];
//    XCTAssertTrue(message.isEphemeral);
//    XCTAssertNotEqual(message.hiddenInConversation, conversation);
//    XCTAssertEqual(message.visibleInConversation, conversation);
//    XCTAssertNotNil(message.sender);
//    XCTAssertNotNil(message.destructionDate);
//    [self.uiMOC saveOrRollback];
//
//    // when
//    [self.sut tearDown];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self setupSUT];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self spinMainQueueWithTimeout:1.5];
//
//    // then
//    [self.uiMOC refreshAllObjects];
//    XCTAssertNotEqual(message.visibleInConversation, conversation);
//    XCTAssertEqual(message.hiddenInConversation, conversation);
//
//    // teardown
//    [self.syncMOC performGroupedBlockAndWait:^{
//        [self.syncMOC zm_teardownMessageObfuscationTimer];
//    }];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//
//    [self.uiMOC performGroupedBlockAndWait:^{
//        [self.uiMOC zm_teardownMessageDeletionTimer];
//    }];
//    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
//}
//
//@end
//
