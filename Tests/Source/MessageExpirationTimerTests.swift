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

//
//
//@import ZMCDataModel;
//@import WireMessageStrategy;
//
//#import "MessagingTest.h"
//
//@interface ZMMessageExpirationTimerTests : MessagingTest
//
//@property (nonatomic) ZMMessageExpirationTimer *sut;
//@property (nonatomic) FakeLocalNotificationDispatcher *mockLocalNotificationDispatcher;
//@end
//
//
//
//@implementation ZMMessageExpirationTimerTests
//
//- (void)setUp
//{
//    [super setUp];
//    self.mockLocalNotificationDispatcher = [[FakeLocalNotificationDispatcher alloc] init];
//
//    self.sut = [[ZMMessageExpirationTimer alloc] initWithManagedObjectContext:self.uiMOC entityName:[ZMClientMessage entityName] localNotificationDispatcher:self.mockLocalNotificationDispatcher];
//}
//
//- (void)tearDown
//{
//    [self.sut tearDown];
//    self.mockLocalNotificationDispatcher = nil;
//    self.sut = nil;
//    [super tearDown];
//}
//
//- (ZMClientMessage *)setupMessageWithExpirationTime:(NSTimeInterval)expirationTime
//{
//    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
//    message.isEncrypted = YES;
//    [ZMMessage setDefaultExpirationTime:expirationTime];
//    [message setExpirationDate];
//    XCTAssertFalse(message.isExpired);
//    XCTAssert([self.uiMOC saveOrRollback]);
//    [ZMMessage resetDefaultExpirationTime];
//    return message;
//}
//
//
//- (void)checkThatMessage:(ZMMessage *)message isExpiredWithFailureRecorder:(ZMTFailureRecorder *)failureRecorder
//{
//    WaitForAllGroupsToBeEmpty(0.5);
//    FHAssertFalse(failureRecorder, message.hasChanges);
//    FHAssertEqualObjects(failureRecorder, message.expirationDate, nil);
//    FHAssertEqual(failureRecorder, message.isExpired, YES);
//}
//
//- (void)waitForMessage:(ZMMessage *)message toExpireWithFailureRecorder:(ZMTFailureRecorder *)failureRecorder
//{
//    FHAssertTrue(failureRecorder, [self waitOnMainLoopUntilBlock:^BOOL{
//        return message.isExpired == YES;
//    } timeout:2.2]);
//}
//
//
//
//
//- (void)testThatItExpiresAMessageImmediately
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:-2];
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//
//    // then
//    [self checkThatMessage:textMessage isExpiredWithFailureRecorder:NewFailureRecorder()];
//}
//
//- (void)testThatItExpiresAMessageWhenItsTimeRunsOut
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.1];
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//    [self waitForMessage:textMessage toExpireWithFailureRecorder:NewFailureRecorder()];
//
//    // then
//    [self checkThatMessage:textMessage isExpiredWithFailureRecorder:NewFailureRecorder()];
//}
//
//#if TARGET_OS_IPHONE
//- (void)testThatItNotifiesTheLocalNotificaitonDispatcherWhenItsTimeRunsOut
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.2];
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//    [self waitForMessage:textMessage toExpireWithFailureRecorder:NewFailureRecorder()];
//
//    // then
//    [self checkThatMessage:textMessage isExpiredWithFailureRecorder:NewFailureRecorder()];
//    [self.mockLocalNotificationDispatcher.failedMessage containsObject:textMessage];
//
//}
//#endif
//
//- (void)testThatItDoesNotExpireAMessageWhenDeliveredIsSetToTrue
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.2];
//    textMessage.delivered = YES;
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//
//    [self spinMainQueueWithTimeout:0.2];
//
//    // then
//    XCTAssertFalse(textMessage.isExpired);
//}
//
//- (void)testThatItExpiresAMessageWhenDeliveredIsNotTrue
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.1];
//    textMessage.delivered = NO;
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//
//    XCTAssertTrue([self waitOnMainLoopUntilBlock:^BOOL{
//        return textMessage.isExpired == YES;
//    } timeout:0.5]);
//
//    // then
//    XCTAssertTrue(textMessage.isExpired);
//}
//
//- (void)testThatItDoesNotExpireAMessageForWhichTheTimerWasStopped
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.2];
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//
//    // when
//    [self.sut stopTimerForMessage:textMessage];
//
//    [self spinMainQueueWithTimeout:0.4];
//
//    // then
//    XCTAssertNotNil(textMessage.expirationDate);
//    XCTAssertFalse(textMessage.isExpired);
//
//}
//
//
//- (void)testThatItDoesNotExpireAMessageThatHasNoExpirationDate
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0];
//    [textMessage removeExpirationDate];
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//
//    [self spinMainQueueWithTimeout:0.2];
//
//    // then
//    XCTAssertNil(textMessage.expirationDate);
//    XCTAssertFalse(textMessage.isExpired);
//}
//
//
//
//- (void)testThatItStartsTimerForStoredMessagesOnFirstRequest
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.2];
//
//    // when
//    [ZMChangeTrackerBootstrap bootStrapChangeTrackers:@[self.sut] onContext:self.uiMOC];
//    [self waitForMessage:textMessage toExpireWithFailureRecorder:NewFailureRecorder()];
//
//    // then
//    XCTAssertNil(textMessage.expirationDate);
//    XCTAssertTrue(textMessage.isExpired);
//}
//
//- (void)testThatItDoesNotHaveMessageTimersRunningWhenThereIsNoMessage
//{
//    XCTAssertFalse(self.sut.hasMessageTimersRunning);
//}
//
//- (void)testThatItDoesNotHaveMessageTimersRunningWhenThereIsNoMessageBecauseTheyAreExpired
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:-2];
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    //then
//    XCTAssertFalse(self.sut.hasMessageTimersRunning);
//}
//
//
//- (void)testThatItDoesNotHaveMessageTimersRunningAfterAMessageExpires
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.01];
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//    XCTAssertTrue([self waitOnMainLoopUntilBlock:^BOOL{
//        return ! self.sut.hasMessageTimersRunning;
//    } timeout:0.5]);
//
//
//    //then
//    XCTAssertFalse(self.sut.hasMessageTimersRunning);
//}
//
//
//- (void)testThatItHasMessageTimersRunningWhenThereIsAMessage
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.7];
//
//    // when
//    [self.sut objectsDidChange:[NSSet setWithObject:textMessage]];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    //then
//    XCTAssertTrue(self.sut.hasMessageTimersRunning);
//}
//
//@end
//
//
//
//@implementation ZMMessageExpirationTimerTests (SlowSync)
//
//- (void)testThatItReturnsCorrectFetchRequest
//{
//    // when
//    NSFetchRequest *request = [self.sut fetchRequestForTrackedObjects];
//
//    // then
//    NSFetchRequest *expected = [ZMMessage sortedFetchRequestWithPredicate:[ZMMessage predicateForMessagesThatWillExpire]];
//    XCTAssertEqualObjects(request, expected);
//}
//
//- (void)testThatItAddsObjectsThatNeedProcessing
//{
//    // given
//    ZMClientMessage *textMessage = [self setupMessageWithExpirationTime:0.4];
//    ZMClientMessage *anotherTextMessage = [self setupMessageWithExpirationTime:0.4];
//
//    // this message should be ignored
//    ZMKnockMessage *knockMessage = [ZMKnockMessage insertNewObjectInManagedObjectContext:self.uiMOC];
//    [ZMMessage setDefaultExpirationTime:0.4];
//    [knockMessage setExpirationDate];
//    XCTAssert([self.uiMOC saveOrRollback]);
//    [ZMMessage resetDefaultExpirationTime];
//
//    XCTAssertFalse(self.sut.hasMessageTimersRunning);
//
//    // when
//    [self.sut addTrackedObjects:[NSSet setWithObjects:textMessage, anotherTextMessage, knockMessage, nil]];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    // then
//    XCTAssertTrue(self.sut.hasMessageTimersRunning);
//    XCTAssertEqual(self.sut.runningTimersCount, 2u);
//}
//
//@end
