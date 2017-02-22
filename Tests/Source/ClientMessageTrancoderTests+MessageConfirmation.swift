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


//@implementation ZMClientMessageTranscoderTests (MessageConfirmation)
//
//- (ZMUpdateEvent *)updateEventForTextMessage:(NSString *)text inConversationWithID:(NSUUID *)conversationID forClient:(UserClient *)client senderClient:(UserClient *)senderClient eventSource:(ZMUpdateEventSource)eventSource
//{
//    ZMGenericMessage *message = [ZMGenericMessage messageWithText:text nonce:[NSUUID createUUID].transportString expiresAfter:nil];
//
//    NSDictionary *payload = @{@"recipient": client.remoteIdentifier, @"sender": senderClient.remoteIdentifier, @"text": message.data.base64String};
//
//    NSDictionary *eventPayload = @{
//                                   @"sender": senderClient.user.remoteIdentifier.transportString,
//                                   @"type":@"conversation.otr-message-add",
//                                   @"data":payload,
//                                   @"conversation":conversationID.transportString,
//                                   @"time":[NSDate dateWithTimeIntervalSince1970:555555].transportString
//                                   };
//    if (eventSource == ZMUpdateEventSourceDownload) {
//        return [ZMUpdateEvent eventFromEventStreamPayload:eventPayload
//                                                     uuid:nil];
//    }
//    return [ZMUpdateEvent eventsArrayFromTransportData:@{@"id" : NSUUID.createUUID.transportString,
//                                                         @"payload" : @[eventPayload]} source:eventSource].firstObject;
//}
//
//- (void)testThatItInsertAConfirmationMessageWhenReceivingAnEvent
//{
//    // given
//    UserClient *client = [self createSelfClient];
//    ZMUser *user1 = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//    user1.remoteIdentifier = [NSUUID createUUID];
//    UserClient *senderClient = [self createClientForUser:user1 createSessionWithSelfUser:YES];
//    [self.syncMOC saveOrRollback];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    NSString *text = @"Everything";
//    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//    conversation.conversationType = ZMTConversationTypeOneOnOne;
//    conversation.remoteIdentifier = [NSUUID createUUID];
//
//    ZMUpdateEvent *updateEvent = [self updateEventForTextMessage:text inConversationWithID:conversation.remoteIdentifier forClient:client senderClient:senderClient eventSource:ZMUpdateEventSourcePushNotification];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    // expect
//    [[self.notificationDispatcher expect] processMessage:OCMOCK_ANY];
//    [[self.notificationDispatcher expect] processGenericMessage:OCMOCK_ANY];
//
//    // when
//    [self.sut processEvents:@[updateEvent] liveEvents:YES prefetchResult:nil];
//
//    // then
//    XCTAssertEqual(conversation.hiddenMessages.count, 1u);
//    ZMClientMessage *confirmationMessage = conversation.hiddenMessages.lastObject;
//    XCTAssertTrue(confirmationMessage.genericMessage.hasConfirmation);
//    XCTAssertEqualObjects(confirmationMessage.genericMessage.confirmation.messageId, updateEvent.messageNonce.transportString);
//}
//
//
//- (void)checkThatItCallsConfirmationStatus:(BOOL)shouldCallConfirmationStatus whenReceivingAnEventThroughSource:(ZMUpdateEventSource)source
//{
//    // given
//    UserClient *client = [self createSelfClient];
//
//    ZMConversation *conversation = [self setupOneOnOneConversation];
//    UserClient *senderClient = [self createClientForUser:conversation.connectedUser createSessionWithSelfUser:YES];
//
//    [self.syncMOC saveOrRollback];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    NSString *text = @"Everything";
//    ZMUpdateEvent *updateEvent = [self updateEventForTextMessage:text inConversationWithID:conversation.remoteIdentifier forClient:client senderClient:senderClient eventSource:source];
//
//    // expect
//    if (shouldCallConfirmationStatus) {
//        [[self.notificationDispatcher expect] processMessage:OCMOCK_ANY];
//        [[self.notificationDispatcher expect] processGenericMessage:OCMOCK_ANY];
//    }
//
//    // when
//    [self.sut processEvents:@[updateEvent] liveEvents:YES prefetchResult:nil];
//
//    // then
//    NSUUID *lastMessageNonce = [conversation.hiddenMessages.lastObject nonce];
//    if (shouldCallConfirmationStatus) {
//        XCTAssertTrue([self.mockAPNSConfirmationStatus.messagesToConfirm containsObject:lastMessageNonce]);
//    } else {
//        XCTAssertFalse([self.mockAPNSConfirmationStatus.messagesToConfirm containsObject:lastMessageNonce]);
//    }
//}
//
//
//- (void)testThatItCallsConfirmationStatusWhenReceivingAnEventThroughPush
//{
//    [self checkThatItCallsConfirmationStatus:YES whenReceivingAnEventThroughSource:ZMUpdateEventSourcePushNotification];
//}
//
//- (void)testThatItCallsConfirmationStatusWhenReceivingAnEventThroughWebSocket
//{
//    [self checkThatItCallsConfirmationStatus:NO whenReceivingAnEventThroughSource:ZMUpdateEventSourceWebSocket];
//}
//
//- (void)testThatItCallsConfirmationStatusWhenReceivingAnEventThroughDownload
//{
//    [self checkThatItCallsConfirmationStatus:NO whenReceivingAnEventThroughSource:ZMUpdateEventSourceDownload];
//}
//
//
//
//- (void)testThatItCallsConfirmationStatusWhenConfirmationMessageIsSentSuccessfully
//{
//    // given
//    [self createSelfClient];
//    ZMConversation *conversation = [self setupOneOnOneConversation];
//
//    ZMMessage *message = (id)[conversation appendMessageWithText:@"text"];
//    ZMClientMessage *confirmationMessage = [(id)message confirmReception];
//    NSUUID *confirmationUUID = confirmationMessage.nonce;
//    [self.sut.upstreamObjectSync objectsDidChange:[NSSet setWithObject:confirmationMessage]];
//
//    // when
//    ZMTransportRequest *request = [self.sut.upstreamObjectSync nextRequest];
//    [request completeWithResponse:[ZMTransportResponse responseWithPayload:@{} HTTPStatus:200 transportSessionError:nil]];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    // then
//    XCTAssertTrue([self.mockAPNSConfirmationStatus.messagesConfirmed containsObject:confirmationUUID]);
//}
//
//- (void)testThatItDeletesTheConfirmationMessageWhenSentSuccessfully
//{
//    // given
//    [self createSelfClient];
//    ZMConversation *conversation = [self setupOneOnOneConversation];
//
//    ZMMessage *message = (id)[conversation appendMessageWithText:@"text"];
//    ZMClientMessage *confirmationMessage = [(id)message confirmReception];
//    [self.sut.upstreamObjectSync objectsDidChange:[NSSet setWithObject:confirmationMessage]];
//
//    // when
//    ZMTransportRequest *request = [self.sut.upstreamObjectSync nextRequest];
//    [request completeWithResponse:[ZMTransportResponse responseWithPayload:@{} HTTPStatus:200 transportSessionError:nil]];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    // then
//    XCTAssertTrue(confirmationMessage.isZombieObject);
//}
//
//- (void)testThatItDoesSyncAConfirmationMessageIfSenderUserIsNotSpecifiedButIsInferedWithConntection;
//{
//    [self createSelfClient];
//    ZMConversation *conversation = [self setupOneOnOneConversation];
//
//    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:@"text" nonce:NSUUID.createUUID.transportString expiresAfter:nil];
//    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.syncMOC];
//    [message addData:genericMessage.data];
//    [conversation sortedAppendMessage:message];
//
//    ZMClientMessage *confirmationMessage = [(id)message confirmReception];
//
//    // when
//    XCTAssertTrue([self.sut shouldCreateRequestToSyncObject:confirmationMessage forKeys:[NSSet set] withSync:self]);
//}
//
//- (void)testThatItDoesSyncAConfirmationMessageIfSenderUserIsSpecified;
//{
//    [self createSelfClient];
//    ZMConversation *conversation = [self setupOneOnOneConversation];
//
//    ZMMessage *message = (id)[conversation appendMessageWithText:@"text"];
//    ZMClientMessage *confirmationMessage = [(id)message confirmReception];
//
//    // when
//    XCTAssertTrue([self.sut shouldCreateRequestToSyncObject:confirmationMessage forKeys:[NSSet set] withSync:self]);
//}
//
//- (void)testThatItDoesSyncAConfirmationMessageIfSenderUserAndConnectIsNotSpecifiedButIsWithConversation;
//{
//    [self createSelfClient];
//    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//    conversation.conversationType = ZMTConversationTypeOneOnOne;
//    conversation.remoteIdentifier = [NSUUID createUUID];
//    [conversation.mutableOtherActiveParticipants addObject:[ZMUser insertNewObjectInManagedObjectContext:self.syncMOC]];
//
//    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:@"text" nonce:NSUUID.createUUID.transportString expiresAfter:nil];
//    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.syncMOC];
//    [message addData:genericMessage.data];
//    [conversation sortedAppendMessage:message];
//
//    ZMClientMessage *confirmationMessage = [(id)message confirmReception];
//
//    // when
//    XCTAssertTrue([self.sut shouldCreateRequestToSyncObject:confirmationMessage forKeys:[NSSet set] withSync:self]);
//}
//
//- (void)testThatItDoesNotSyncAConfirmationMessageIfCannotInferUser;
//{
//    [self createSelfClient];
//    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//    conversation.conversationType = ZMTConversationTypeOneOnOne;
//    conversation.remoteIdentifier = [NSUUID createUUID];
//
//    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:@"text" nonce:NSUUID.createUUID.transportString expiresAfter:nil];
//    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.syncMOC];
//    [message addData:genericMessage.data];
//    [conversation sortedAppendMessage:message];
//
//    ZMClientMessage *confirmationMessage = [(id)message confirmReception];
//
//    // when
//    XCTAssertFalse([self.sut shouldCreateRequestToSyncObject:confirmationMessage forKeys:[NSSet set] withSync:self]);
//}
//
//@end
