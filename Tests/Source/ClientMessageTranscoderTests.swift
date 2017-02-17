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
import WireRequestStrategy

class ClientMessageTranscoderTests: MessagingTest {

    var clientRegistrationStatus: ClientRegistrationDelegate!
    var localNotificationDispatcher: MockPushMessageHandler!
    var confirmationStatus: MockConfirmationStatus!
    var sut: ClientMessageTranscoder!
    var groupConversation: ZMConversation!
    var oneToOneConversation: ZMConversation!
    var user: ZMUser!
    
    override func setUp() {
        super.setUp()
        self.localNotificationDispatcher = MockPushMessageHandler()
        self.clientRegistrationStatus = MockClientRegistrationStatus()
        self.confirmationStatus = MockConfirmationStatus()
        
        self.user = self.createUser()
        self.groupConversation = self.createGroupConversation(with: self.user)
        self.oneToOneConversation = self.setupOneToOneConversation(with: self.user)
        
        self.sut = ClientMessageTranscoder(in: self.syncMOC, localNotificationDispatcher: self.localNotificationDispatcher, clientRegistrationStatus: self.clientRegistrationStatus, apnsConfirmationStatus: self.confirmationStatus)
        
        self.syncMOC.saveOrRollback()
    }
    
    override func tearDown() {
        self.localNotificationDispatcher = nil
        self.clientRegistrationStatus = nil
        self.confirmationStatus = nil
        self.user = nil
        self.groupConversation = nil
        self.sut.tearDown()
        self.sut = nil
        super.tearDown()
    }
    
    private func setupOneToOneConversation(with user: ZMUser) -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
        conversation.conversationType = .oneOnOne
        conversation.remoteIdentifier = UUID.create()
        conversation.connection = ZMConnection.insertNewObject(in: self.syncMOC)
        conversation.connection!.to = user
        return conversation
    }
}

//
//@interface FakeClientMessageRequestFactory : NSObject
//
//@end
//
//@implementation FakeClientMessageRequestFactory
//
//- (ZMTransportRequest *)upstreamRequestForAssetMessage:(ZMImageFormat __unused)format message:(ZMAssetClientMessage *__unused)message forConversationWithId:(NSUUID *__unused)conversationId
//{
//    return nil;
//}
//
//
//@end
//
//
//
//@interface ZMClientMessageTranscoderTests : ZMMessageTranscoderTests
//
//@property (nonatomic) id<ClientRegistrationDelegate> mockClientRegistrationStatus;
//@property (nonatomic) MockConfirmationStatus *mockAPNSConfirmationStatus;
//@property (nonatomic) id<PushMessageHandler> mockNotificationDispatcher;
//
//- (ZMConversation *)setupOneOnOneConversation;
//
//@end
//
//
//@implementation ZMClientMessageTranscoderTests
//
//- (void)setUp
//{
//    [super setUp];
//    self.mockAPNSConfirmationStatus = [[MockConfirmationStatus alloc] init];
//    self.mockClientRegistrationStatus = [OCMockObject mockForProtocol:@protocol(ClientRegistrationDelegate)];
//    self.mockNotificationDispatcher = [OCMockObject niceMockForProtocol:@protocol(PushMessageHandler)];
//    [self setupSUT];
//
//    [[self.mockExpirationTimer stub] tearDown];
//    [self verifyMockLater:self.mockClientRegistrationStatus];
//}
//
//- (void)setupSUT
//{
//    self.sut = [[ZMClientMessageTranscoder alloc] initWithManagedObjectContext:self.syncMOC
//                                                   localNotificationDispatcher:self.notificationDispatcher
//                                                      clientRegistrationStatus:self.mockClientRegistrationStatus
//                                                        apnsConfirmationStatus:self.mockAPNSConfirmationStatus];
//}
//
//- (void)tearDown
//{
//    [self.sut tearDown];
//    self.sut = nil;
//    [super tearDown];
//}
//

//
//
//- (ZMConversation *)setupOneOnOneConversation
//{
//    return [self setupOneOnOneConversationInContext:self.syncMOC];
//}
//

// MARK: - Dependency
extension ClientMessageTranscoderTests {
 
    func testThatItReturnsSelfClientAsDependentObjectForMessageIfItHasMissingClients() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let selfClient = self.createSelfClient()
            let missingClient = self.createClient(for: self.user, createSessionWithSelfUser: false)
            let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage
            
            // WHEN
            selfClient.missesClient(missingClient)
            
            // THEN
            let dependency = self.sut.dependentObjectNeedingUpdate(beforeProcessingObject: message)
            XCTAssertEqual(dependency as? UserClient, selfClient)
        }
    }
    
    func testThatItReturnsConversationIfNeedsToBeUpdatedFromBackendBeforeMissingClients() {
        self.syncMOC.performGroupedBlockAndWait {

            // GIVEN
            let selfClient = self.createSelfClient()
            let missingClient = self.createClient(for: self.user, createSessionWithSelfUser: false)
            let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage

            // WHEN
            selfClient.missesClient(missingClient)
            self.groupConversation.needsToBeUpdatedFromBackend = true
            
            // THEN
            let dependency = self.sut.dependentObjectNeedingUpdate(beforeProcessingObject: message)
            XCTAssertEqual(dependency as? ZMConversation, self.groupConversation)
        }
    }
    
    func testThatItReturnsConnectionIfNeedsToBeUpdatedFromBackendBeforeMissingClients() {
        self.syncMOC.performGroupedBlockAndWait {

            // GIVEN
            let selfClient = self.createSelfClient()
            let missingClient = self.createClient(for: self.user, createSessionWithSelfUser: false)
            let message = self.oneToOneConversation.appendMessage(withText: "foo") as! ZMClientMessage
            
            // WHEN
            selfClient.missesClient(missingClient)
            self.oneToOneConversation.connection?.needsToBeUpdatedFromBackend = true
            
            // THEN
            let dependency = self.sut.dependentObjectNeedingUpdate(beforeProcessingObject: message)
            XCTAssertEqual(dependency as? ZMConnection, self.oneToOneConversation.connection)
        }
    }
    
    func testThatItDoesNotReturnSelfClientAsDependentObjectForMessageIfConversationIsNotAffectedByMissingClients() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let selfClient = self.createSelfClient()
            let missingClient = self.createClient(for: self.user, createSessionWithSelfUser: false)
            let user2 = self.createUser()
            let conversation2 = self.createGroupConversation(with: user2)
            let message = conversation2.appendMessage(withText: "foo") as! ZMClientMessage
            
            // WHEN
            selfClient.missesClient(missingClient)
            
            // THEN
            let dependency = self.sut.dependentObjectNeedingUpdate(beforeProcessingObject: message)
            XCTAssertNil(dependency)
        }
    }
    
    func testThatItReturnsNilAsDependentObjectForMessageIfItHasNoMissingClients() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage
            
            // THEN
            let dependency = self.sut.dependentObjectNeedingUpdate(beforeProcessingObject: message)
            XCTAssertNil(dependency)
        }
    }
    
    func testThatItReturnsAPreviousPendingMessageAsDependency() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let timeZero = Date(timeIntervalSince1970: 10000)
            let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage
            message.serverTimestamp = timeZero
            message.markAsSent()
            
            let nextMessage = self.groupConversation.appendMessage(withText: "bar") as! ZMClientMessage
            // nextMessage.serverTimestamp = timeZero.addingTimeInterval(100) // this ensures the sorting
            
            // WHEN
            let lastMessage = self.groupConversation.appendMessage(withText: "zoo") as! ZMClientMessage
            
            // THEN
            let dependency = self.sut.dependentObjectNeedingUpdate(beforeProcessingObject: lastMessage)
            XCTAssertEqual(dependency as? ZMClientMessage, nextMessage)
        }
    }
    
    func testThatItDoesNotReturnAPreviousSentMessageAsDependency() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let timeZero = Date(timeIntervalSince1970: 10000)
            let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage
            message.serverTimestamp = timeZero
            message.markAsSent()
            
            // WHEN
            let lastMessage = self.groupConversation.appendMessage(withText: "zoo") as! ZMClientMessage
            
            // THEN
            let dependency = self.sut.dependentObjectNeedingUpdate(beforeProcessingObject: lastMessage)
            XCTAssertNil(dependency)
        }
    }
}

// MARK: - Request generation

extension ClientMessageTranscoderTests {
    
    func testThatItGeneratesARequestToSendAClientMessage() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            self.createSelfClient()
            self.createClient(for: self.user, createSessionWithSelfUser: true)
            let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage
            self.syncMOC.saveOrRollback()
            
            // WHEN
            self.sut.contextChangeTrackers.forEach { $0.objectsDidChange(Set([message])) }
            guard let request = self.sut.nextRequest() else {
                XCTFail()
                return
            }
            
            // THEN
            XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
            XCTAssertEqual(request.method, .methodPOST)
            XCTAssertNotNil(request.binaryData)
            XCTAssertEqual(request.binaryDataType, "application/x-protobuf")
        }
    }
    
    
    func testThatANewOtrMessageIsCreatedFromAnEvent() {
        self.syncMOC.performGroupedBlockAndWait {
         
            // GIVEN
            let client = self.createSelfClient()
            let text = "Everything"
            let base64Text = "CiQ5ZTU2NTQwOS0xODZiLTRlN2YtYTE4NC05NzE4MGE0MDAwMDQSDAoKRXZlcnl0aGluZw=="
            let payload = [
                "recipient": client.remoteIdentifier,
                "sender": client.remoteIdentifier,
                "text": base64Text
            ]
            let eventPayload = [
                "type": "conversation.otr-message-add",
                "payload": payload,
                "conversation": self.groupConversation.remoteIdentifier!.transportString(),
                "time": Date().transportString()
            ] as NSDictionary
            guard let event = ZMUpdateEvent.decryptedUpdateEvent(fromEventStreamPayload: eventPayload, uuid: nil, transient: false, source: .webSocket) else {
                XCTFail()
                return
            }
            
            // WHEN
            self.sut.processEvents([event], liveEvents: false, prefetchResult: nil)
            
            // THEN
            XCTAssertEqual((self.groupConversation.messages.lastObject as? ZMConversationMessage)?.textMessageData?.messageText, text)
        }
    }
}

// TODO MARCO

//
//- (void)testThatANewOtrMessageIsCreatedFromAnEvent
//{
//    [self.syncMOC performGroupedBlock:^{
//
//        // given
//        UserClient *client = [self createSelfClient];
//        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        conversation.remoteIdentifier = [NSUUID createUUID];
//        [self.syncMOC saveOrRollback];
//
//        NSString *text = @"Everything";
//        NSString *base64String = @"CiQ5ZTU2NTQwOS0xODZiLTRlN2YtYTE4NC05NzE4MGE0MDAwMDQSDAoKRXZlcnl0aGluZw==";
//        NSDictionary *payload = @{@"recipient": client.remoteIdentifier, @"sender": client.remoteIdentifier, @"text": base64String};
//        NSDictionary *eventPayload = @{@"type":         @"conversation.otr-message-add",
//                                       @"data":         payload,
//                                       @"conversation": conversation.remoteIdentifier.transportString,
//                                       @"time":         [NSDate dateWithTimeIntervalSince1970:555555].transportString
//                                       };
//        ZMUpdateEvent *updateEvent = [ZMUpdateEvent decryptedUpdateEventFromEventStreamPayload:eventPayload uuid:[NSUUID createUUID] transient:NO source:ZMUpdateEventSourceWebSocket];
//
//        // when
//        [self.sut processEvents:@[updateEvent] liveEvents:NO prefetchResult:nil];
//
//        // then
//        XCTAssertEqualObjects([conversation.messages.lastObject messageText], text);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatANewOtrMessageIsCreatedFromADecryptedAPNSEvent
//{
//    [self.syncMOC performGroupedBlock:^{
//        // given
//        UserClient *client = [self createSelfClient];
//        UserClient *otherClient = [self createClientForUser:[ZMUser insertNewObjectInManagedObjectContext:self.syncMOC] createSessionWithSelfUser:NO];
//        NSString *text = @"Everything";
//        NSUUID *conversationID = [NSUUID createUUID];
//        [self.syncMOC saveOrRollback];
//
//        //create encrypted message
//        ZMGenericMessage *message = [ZMGenericMessage messageWithText:text nonce:[NSUUID createUUID].transportString expiresAfter:nil];
//        NSData *encryptedData = [self encryptedMessageToSelfWithMessage:message fromSender:otherClient];
//
//        NSDictionary *payload = @{@"recipient": client.remoteIdentifier, @"sender": otherClient.remoteIdentifier, @"text": [encryptedData base64String]};
//        ZMUpdateEvent *updateEvent = [ZMUpdateEvent eventFromEventStreamPayload:
//                                      @{
//                                        @"type":@"conversation.otr-message-add",
//                                        @"from":otherClient.user.remoteIdentifier.transportString,
//                                        @"data":payload,
//                                        @"conversation":conversationID.transportString,
//                                        @"time":[NSDate dateWithTimeIntervalSince1970:555555].transportString
//                                        } uuid:nil];
//
//        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        conversation.remoteIdentifier = conversationID;
//        [self.syncMOC saveOrRollback];
//
//        __block ZMUpdateEvent *decryptedEvent;
//        [self.syncMOC.zm_cryptKeyStore.encryptionContext perform:^(EncryptionSessionsDirectory * _Nonnull sessionsDirectory) {
//            decryptedEvent = [sessionsDirectory decryptUpdateEventAndAddClient:updateEvent managedObjectContext:self.syncMOC];
//        }];
//
//        // when
//        [self.sut processEvents:@[decryptedEvent] liveEvents:NO prefetchResult:nil];
//
//        // then
//        XCTAssertEqualObjects([conversation.messages.lastObject messageText], text);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItGeneratesARequestToSendAClientMessageExternalWithExternalBlob
//{
//    NSString *longText = [@"Hello" stringByPaddingToLength:10000 withString:@"?" startingAtIndex:0];
//    [self checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithText:longText block:^(ZMMessage *message) {
//        [self.sut.contextChangeTrackers[0] objectsDidChange:@[message].set];
//    }];
//}
//
//- (void)testThatItGeneratesARequestToSendAClientMessageWhenAMessageIsInsertedWithBlock:(void(^)(ZMMessage *message))block
//{
//    [self.syncMOC performGroupedBlock:^{
//
//        // given
//        [self createSelfClient];
//        ZMConversation *conversation = [self insertGroupConversation];
//        ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:@"foo" nonce:[NSUUID createUUID].transportString expiresAfter:nil];
//
//        ZMClientMessage *message = [conversation appendClientMessageWithData:genericMessage.data];
//        message.isEncrypted = YES;
//        XCTAssertTrue([self.syncMOC saveOrRollback]);
//
//        // when
//        block(message);
//        ZMTransportRequest *request = [self.sut.requestGenerators nextRequest];
//
//        // then
//        //POST /conversations/{cnv}/messages
//        NSString *expectedPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.remoteIdentifier.transportString, @"otr", @"messages"]];
//        XCTAssertNotNil(request);
//        XCTAssertEqualObjects(expectedPath, request.path);
//        XCTAssertNotNil(request.binaryData);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//
//- (void)checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithBlock:(void(^)(ZMMessage *message))block
//{
//    [self checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithText:@"foo" block:block];
//}
//
//- (void)checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithText:(NSString *)messageText block:(void(^)(ZMMessage *message))block
//{
//    // given
//    __block ZMConversation *conversation;
//    __block ZMClientMessage *message;
//
//    [self.syncMOC performGroupedBlock:^{
//        conversation = self.insertGroupConversation;
//        message = [conversation appendOTRMessageWithText:messageText nonce:[NSUUID createUUID]fetchLinkPreview:@YES];
//    }];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    XCTAssertNotNil(message);
//    XCTAssertNotNil(conversation);
//
//    __block UserClient *selfClient;
//
//    [self.syncMOC performGroupedBlock:^{
//        conversation = [ZMConversation fetchObjectWithRemoteIdentifier:conversation.remoteIdentifier inManagedObjectContext:self.syncMOC];
//        selfClient = self.createSelfClient;
//
//        //other user client
//        [conversation.otherActiveParticipants enumerateObjectsUsingBlock:^(ZMUser *user, NSUInteger __unused idx, BOOL *__unused stop) {
//            UserClient *userClient = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
//            userClient.remoteIdentifier = [NSString createAlphanumericalString];
//            userClient.user = user;
//            [self establishSessionFromSelfToClient:userClient];
//        }];
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//    XCTAssertNotNil(selfClient);
//
//    // when
//    block(message);
//
//    __block ZMTransportRequest *request;
//    [self.syncMOC performGroupedBlock:^{
//        request = [self.sut.requestGenerators nextRequest];
//    }];
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    // then we expect a POST request to /conversations/{cnv}/otr/messages
//    NSArray *pathComponents = @[@"/", @"conversations", conversation.remoteIdentifier.transportString, @"otr", @"messages"];
//    NSString *expectedPath = [NSString pathWithComponents:pathComponents];
//    XCTAssertNotNil(request);
//    XCTAssertEqualObjects(expectedPath, request.path);
//
//    ZMClientMessage *syncMessage = (ZMClientMessage *)[self.sut.managedObjectContext objectWithID:message.objectID];
//    ZMNewOtrMessage *expectedOtrMessageMetadata = (ZMNewOtrMessage *)[ZMNewOtrMessage.builder mergeFromData:syncMessage.encryptedMessagePayloadDataOnly].build;
//    ZMNewOtrMessage *otrMessageMetadata = (ZMNewOtrMessage *)[ZMNewOtrMessage.builder mergeFromData:request.binaryData].build;
//    [self assertNewOtrMessageMetadata:otrMessageMetadata expected:expectedOtrMessageMetadata conversation:conversation];
//}
//
//- (void)assertNewOtrMessageMetadata:(ZMNewOtrMessage *)otrMessageMetadata expected:(ZMNewOtrMessage *)expectedOtrMessageMetadata conversation:(ZMConversation *)conversation
//{
//    NSArray *userIds = [otrMessageMetadata.recipients mapWithBlock:^id(ZMUserEntry *entry) {
//        return [[NSUUID alloc] initWithUUIDBytes:entry.user.uuid.bytes];
//    }];
//
//    NSArray *expectedUserIds = [expectedOtrMessageMetadata.recipients mapWithBlock:^id(ZMUserEntry *entry) {
//        return [[NSUUID alloc] initWithUUIDBytes:entry.user.uuid.bytes];
//    }];
//
//    AssertArraysContainsSameObjects(userIds, expectedUserIds);
//
//    NSArray *recipientsIds = [otrMessageMetadata.recipients flattenWithBlock:^NSArray *(ZMUserEntry *entry) {
//        return [entry.clients mapWithBlock:^NSNumber *(ZMClientEntry *clientEntry) {
//            return @(clientEntry.client.client);
//        }];
//    }];
//
//    NSArray *expectedRecipientsIds = [expectedOtrMessageMetadata.recipients flattenWithBlock:^NSArray *(ZMUserEntry *entry) {
//        return [entry.clients mapWithBlock:^NSNumber *(ZMClientEntry *clientEntry) {
//            return @(clientEntry.client.client);
//        }];
//    }];
//
//    AssertArraysContainsSameObjects(recipientsIds, expectedRecipientsIds);
//
//    NSArray *conversationUserIds = [conversation.otherActiveParticipants.array mapWithBlock:^id(ZMUser *obj) {
//        return [obj remoteIdentifier];
//    }];
//    AssertArraysContainsSameObjects(userIds, conversationUserIds);
//
//    NSArray *conversationRecipientsIds = [conversation.otherActiveParticipants.array flattenWithBlock:^NSArray *(ZMUser *obj) {
//        return [obj.clients.allObjects mapWithBlock:^NSString *(UserClient *client) {
//            return client.remoteIdentifier;
//        }];
//    }];
//
//    NSArray *stringRecipientsIds = [recipientsIds mapWithBlock:^NSString *(NSNumber *obj) {
//        return [NSString stringWithFormat:@"%lx", (unsigned long)[obj unsignedIntegerValue]];
//    }];
//
//    AssertArraysContainsSameObjects(stringRecipientsIds, conversationRecipientsIds);
//
//    XCTAssertEqual(otrMessageMetadata.nativePush, expectedOtrMessageMetadata.nativePush);
//}
//
//- (void)assertOtrAssetMetadata:(ZMOtrAssetMeta *)otrAssetMetadata expected:(ZMOtrAssetMeta *)expectedOtrAssetMetadata conversation:(ZMConversation *)conversation
//{
//    [self assertNewOtrMessageMetadata:(ZMNewOtrMessage *)otrAssetMetadata expected:(ZMNewOtrMessage *)expectedOtrAssetMetadata conversation:conversation];
//
//    XCTAssertEqual(otrAssetMetadata.isInline, expectedOtrAssetMetadata.isInline);
//}
//
//- (void)testThatItGeneratesARequestToSendAMessageWhenAGenericMessageIsInserted_OnInitialization
//{
//    [self testThatItGeneratesARequestToSendAClientMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
//        NOT_USED(message);
//        [ZMChangeTrackerBootstrap bootStrapChangeTrackers:self.sut.contextChangeTrackers onContext:self.syncMOC];
//    }];
//}
//
//- (void)testThatItGeneratesARequestToSendAMessageWhenAGenericMessageIsInserted_OnObjectsDidChange
//{
//    [self testThatItGeneratesARequestToSendAClientMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
//        NOT_USED(message);
//        [self.sut.contextChangeTrackers[0] objectsDidChange:[NSSet setWithObject:message]];
//    }];
//}
//
//- (void)testThatItGeneratesARequestToSendAMessageWhenOTRMessageIsInserted_OnInitialization
//{
//    [self checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
//        NOT_USED(message);
//        [ZMChangeTrackerBootstrap bootStrapChangeTrackers:self.sut.contextChangeTrackers onContext:self.syncMOC];
//    }];
//}
//
//- (void)testThatItGeneratesARequestToSendAMessageWhenOTRMessageIsInserted_OnObjectsDidChange
//{
//    [self checkThatItGeneratesARequestToSendOTRMessageWhenAMessageIsInsertedWithBlock:^(ZMMessage *message) {
//        NSManagedObject *syncMessage = [self.sut.managedObjectContext objectWithID:message.objectID];
//        for(id changeTracker in self.sut.contextChangeTrackers) {
//            [changeTracker objectsDidChange:[NSSet setWithObject:syncMessage]];
//        }
//    }];
//}
//
//- (ZMAssetClientMessage *)bootstrapAndCreateOTRAssetMessageInConversationWithId:(NSUUID *)conversationId
//{
//    ZMConversation *conversation = [self insertGroupConversationInMoc:self.syncMOC];
//    conversation.remoteIdentifier = conversationId;
//    return [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
//}
//
//
//- (ZMAssetClientMessage *)bootstrapAndCreateOTRAssetMessageInConversation:(ZMConversation *)conversation
//{
//    // given
//    NSData *imageData = [self verySmallJPEGData];
//    ZMAssetClientMessage *message = [self createImageMessageWithImageData:imageData format:ZMImageFormatMedium processed:YES stored:NO encrypted:YES moc:self.syncMOC];
//    [conversation.mutableMessages addObject:message];
//    XCTAssertTrue([self.syncMOC saveOrRollback]);
//
//    //self client
//    [self createSelfClient];
//
//    //other user client
//    [conversation.otherActiveParticipants enumerateObjectsUsingBlock:^(ZMUser *user, NSUInteger __unused idx, BOOL *__unused stop) {
//        [self createClientForUser:user createSessionWithSelfUser:YES];
//    }];
//
//    XCTAssertTrue([self.syncMOC saveOrRollback]);
//    return message;
//}
//
//- (void)testThatItAddsMissingRecipientInMessageRelationship
//{
//    [self.syncMOC performGroupedBlock:^{
//        // given
//        ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
//
//        NSString *missingClientId = [NSString createAlphanumericalString];
//        NSDictionary *payload = @{@"missing": @{[NSUUID createUUID].transportString : @[missingClientId]}};
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:412 transportSessionError:nil];
//        ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//        // when
//        [self.sut shouldRetryToSyncAfterFailedToUpdateObject:message request:request response:response keysToParse:[NSSet set]];
//
//        // then
//        UserClient *missingClient = message.missingRecipients.anyObject;
//        XCTAssertNotNil(missingClient);
//        XCTAssertEqualObjects(missingClient.remoteIdentifier, missingClientId);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItDeletesTheCurrentClientIfWeGetA403ResponseWithCorrectLabel
//{
//    [self.syncMOC performGroupedBlock:^{
//
//        // given
//        ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
//        id <ZMTransportData> payload = @{ @"label": @"unknown-client" };
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:403 transportSessionError:nil];
//        ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//        // expect
//        [[(id)self.mockClientRegistrationStatus expect] didDetectCurrentClientDeletion];
//
//        // when
//        [self.sut shouldRetryToSyncAfterFailedToUpdateObject:message request:request response:response keysToParse:[NSSet set]];
//
//        // then
//        [(id)self.mockClientRegistrationStatus verify];
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItDoesNotDeletesTheCurrentClientIfWeGetA403ResponseWithoutTheCorrectLabel
//    {
//        [self.syncMOC performGroupedBlock:^{
//
//            // given
//            ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
//            ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@[] HTTPStatus:403 transportSessionError:nil];
//            ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//            // reject
//            [[(id)self.mockClientRegistrationStatus reject] didDetectCurrentClientDeletion];
//
//            // when
//            [self.sut shouldRetryToSyncAfterFailedToUpdateObject:message request:request response:response keysToParse:[NSSet set]];
//
//            // then
//            [(id)self.mockClientRegistrationStatus verify];
//        }];
//
//        WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItSetsNeedsToBeUpdatedFromBackendOnConversationIfMissingMapIncludesUsersThatAreNoActiveUsers
//{
//    [self.syncMOC performGroupedBlock:^{
//
//        // given
//        ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversationWithId:[NSUUID createUUID]];
//        XCTAssertFalse(message.conversation.needsToBeUpdatedFromBackend);
//
//        NSString *missingClientId = [NSString createAlphanumericalString];
//        NSDictionary *payload = @{@"missing": @{[NSUUID createUUID].transportString : @[missingClientId]}};
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:412 transportSessionError:nil];
//        ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//        // when
//        [self.sut shouldRetryToSyncAfterFailedToUpdateObject:message request:request response:response keysToParse:[NSSet set]];
//
//        // then
//        XCTAssertTrue(message.conversation.needsToBeUpdatedFromBackend);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItSetsNeedsToBeUpdatedFromBackendOnConnectionIfMissingMapIncludesUsersThatIsNoActiveUser_OneOnOne
//{
//    [self.syncMOC performGroupedBlock:^{
//        // given
//        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        conversation.conversationType = ZMConversationTypeOneOnOne;
//        conversation.remoteIdentifier = [NSUUID UUID];
//        conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.syncMOC];
//        ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//        user.remoteIdentifier = [NSUUID UUID];
//
//        ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
//        XCTAssertFalse(message.conversation.connection.needsToBeUpdatedFromBackend);
//
//        NSString *missingClientId = [NSString createAlphanumericalString];
//        NSDictionary *payload = @{@"missing": @{user.remoteIdentifier.transportString : @[missingClientId]}};
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:412 transportSessionError:nil];
//        ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//
//        // when
//        [self.sut shouldRetryToSyncAfterFailedToUpdateObject:message request:request response:response keysToParse:[NSSet set]];
//        [self.syncMOC saveOrRollback];
//
//        // then
//        XCTAssertNotNil(user.connection);
//        XCTAssertNotNil(message.conversation.connection);
//        XCTAssertTrue(message.conversation.connection.needsToBeUpdatedFromBackend);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItInsertsAndSetsNeedsToBeUpdatedFromBackendOnConnectionIfMissingMapIncludesUsersThatIsNoActiveUser_OneOnOne
//{
//    [self.syncMOC performGroupedBlock:^{
//        // given
//        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        conversation.conversationType = ZMConversationTypeOneOnOne;
//        conversation.remoteIdentifier = [NSUUID UUID];
//
//        ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//        user.remoteIdentifier = [NSUUID UUID];
//
//        ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
//        XCTAssertFalse(message.conversation.needsToBeUpdatedFromBackend);
//
//        NSString *missingClientId = [NSString createAlphanumericalString];
//        NSDictionary *payload = @{@"missing": @{user.remoteIdentifier.transportString : @[missingClientId]}};
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:412 transportSessionError:nil];
//        ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//        // when
//        [self.sut shouldRetryToSyncAfterFailedToUpdateObject:message request:request response:response keysToParse:[NSSet set]];
//        [self.syncMOC saveOrRollback];
//
//        // then
//        XCTAssertNotNil(user.connection);
//        XCTAssertNotNil(message.conversation.connection);
//        XCTAssertTrue(message.conversation.connection.needsToBeUpdatedFromBackend);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItDeletesDeletedRecipientsOnFailure
//{
//    // given
//    [self.syncMOC performGroupedBlock:^{
//        UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
//        client.remoteIdentifier = @"whoopy";
//        client.user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//
//        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
//
//        ZMUser *user = client.user;
//        user.remoteIdentifier = [NSUUID createUUID];
//
//        NSDictionary *payload = @{@"deleted": @{user.remoteIdentifier.transportString : @[client.remoteIdentifier]}};
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:412 transportSessionError:nil];
//        ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//        // when
//        [self.sut shouldRetryToSyncAfterFailedToUpdateObject:message request:request response:response keysToParse:[NSSet set]];
//        [self.syncMOC saveOrRollback];
//
//        // then
//        XCTAssertTrue(client.isZombieObject);
//        XCTAssertEqual(user.clients.count, 0u);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItDeletesDeletedRecipientsOnSuccessInsertion
//{
//    [self.syncMOC performGroupedBlock:^{
//
//        // given
//        UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
//        client.remoteIdentifier = @"whoopy";
//        client.user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//
//        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        ZMAssetClientMessage *message = [self bootstrapAndCreateOTRAssetMessageInConversation:conversation];
//
//        ZMUser *user = client.user;
//        user.remoteIdentifier = [NSUUID createUUID];
//
//        NSDictionary *payload = @{@"deleted": @{user.remoteIdentifier.transportString : @[client.remoteIdentifier]}};
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
//        ZMUpstreamRequest *request = [[ZMUpstreamRequest alloc] initWithTransportRequest:[ZMTransportRequest requestGetFromPath:@"foo"]];
//
//        // when
//        [self.sut updateInsertedObject:message request:request response:response];
//        [self.syncMOC saveOrRollback];
//
//        // then
//        XCTAssertTrue(client.isZombieObject);
//        XCTAssertEqual(user.clients.count, 0u);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItDeletesDeletedRecipientsOnSuccessUpdate
//{
//    [self.syncMOC performGroupedBlock:^{
//
//        // given
//        ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.syncMOC];
//        message.visibleInConversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
//        client.remoteIdentifier = @"whoopy";
//        client.user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//
//        ZMUser *user = client.user;
//        user.remoteIdentifier = [NSUUID createUUID];
//
//        [self.syncMOC saveOrRollback];
//
//        NSDictionary *payload = @{
//                                  @"time" : [NSDate date].transportString,
//                                  @"deleted": @{user.remoteIdentifier.transportString : @[client.remoteIdentifier]}
//                                  };
//        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
//
//        // when
//        [self.sut updateUpdatedObject:message requestUserInfo:[NSDictionary dictionary] response:response keysToParse:[NSSet set]];
//        [self.syncMOC saveOrRollback];
//
//        // then
//        XCTAssertTrue(client.isZombieObject);
//        XCTAssertEqual(user.clients.count, 0u);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//@end
//
//
//@implementation ZMClientMessageTranscoderTests (ClientsTrust)
//
//- (NSArray *)createGroupConversationUsersWithClients
//{
//    self.selfUser = [ZMUser selfUserInContext:self.syncMOC];
//
//    ZMUser *user1 = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//    UserClient *userClient1 = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
//    ZMConnection *firstConnection = [ZMConnection insertNewSentConnectionToUser:user1];
//    firstConnection.status = ZMConnectionStatusAccepted;
//    userClient1.user = user1;
//
//    ZMUser *user2 = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
//    UserClient *userClient2 = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
//    ZMConnection *secondConnection = [ZMConnection insertNewSentConnectionToUser:user2];
//    secondConnection.status = ZMConnectionStatusAccepted;
//    userClient2.user = user2;
//
//    return @[user1, user2];
//}
//
//- (ZMMessage *)createMessageInGroupConversationWithUsers:(NSArray *)users encrypted:(BOOL)encrypted
//{
//    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.syncMOC];
//    message.isEncrypted = encrypted;
//
//    ZMConversation *conversation = [ZMConversation insertGroupConversationIntoManagedObjectContext:self.syncMOC withParticipants:users];
//    [conversation.mutableMessages addObject:message];
//    return message;
//}
//
//
//@end
//
//
//
//@implementation ZMClientMessageTranscoderTests (ZMLastRead)
//
//- (void)testThatItPicksUpLastReadUpdateMessages
//{
//    // given
//    [self.syncMOC performGroupedBlockAndWait:^{
//        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
//        selfUser.remoteIdentifier = [NSUUID createUUID];
//        ZMConversation *selfConversation = [ZMConversation conversationWithRemoteID:selfUser.remoteIdentifier createIfNeeded:YES inContext:self.syncMOC];
//        selfConversation.conversationType = ZMConversationTypeSelf;
//        [self createSelfClient];
//
//        NSDate *lastRead = [NSDate date];
//        ZMConversation *updatedConversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        updatedConversation.remoteIdentifier = [NSUUID createUUID];
//        updatedConversation.lastReadServerTimeStamp = lastRead;
//
//        ZMClientMessage *lastReadUpdateMessage = [ZMConversation appendSelfConversationWithLastReadOfConversation:updatedConversation];
//        XCTAssertNotNil(lastReadUpdateMessage);
//
//        // when
//        for (id tracker in self.sut.contextChangeTrackers) {
//            [tracker objectsDidChange:[NSSet setWithObject:lastReadUpdateMessage]];
//        }
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//
//    [self.syncMOC performGroupedBlockAndWait:^{
//        ZMTransportRequest *request = [self.sut.requestGenerators.firstObject nextRequest];
//
//        // then
//        XCTAssertNotNil(request);
//    }];
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//- (void)testThatItCreatesARequestForLastReadUpdateMessages
//{
//    // given
//    [self.syncMOC performGroupedBlockAndWait:^{
//        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
//        selfUser.remoteIdentifier = [NSUUID createUUID];
//        ZMConversation *selfConversation = [ZMConversation conversationWithRemoteID:selfUser.remoteIdentifier createIfNeeded:YES inContext:self.syncMOC];
//        selfConversation.conversationType = ZMConversationTypeSelf;
//        [self createSelfClient];
//
//        NSDate *lastRead = [NSDate date];
//        ZMConversation *updatedConversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        updatedConversation.remoteIdentifier = [NSUUID createUUID];
//        updatedConversation.lastReadServerTimeStamp = lastRead;
//
//        ZMClientMessage *lastReadUpdateMessage = [ZMConversation appendSelfConversationWithLastReadOfConversation:updatedConversation];
//        XCTAssertNotNil(lastReadUpdateMessage);
//        [[self.mockExpirationTimer stub] stopTimerForMessage:lastReadUpdateMessage];
//
//        // when
//        ZMUpstreamRequest *request = [(id<ZMUpstreamTranscoder>)self.sut requestForInsertingObject:lastReadUpdateMessage forKeys:nil];
//
//        // then
//        XCTAssertNotNil(request);
//    }];
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//
//@end
//
//
//@implementation ZMClientMessageTranscoderTests (GenericMessageData)
//
//- (void)testThatThePreviewGenericMessageDataHasTheOriginalSizeOfTheMediumGenericMessagedata
//{
//    [self.syncMOC performGroupedBlockAndWait:^{
//
//        // given
//        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
//        ZMAssetClientMessage *message = [conversation appendOTRMessageWithImageData:[self dataForResource:@"1900x1500" extension:@"jpg"] nonce:[NSUUID createUUID]];
//        [[(id)self.upstreamObjectSync stub] objectsDidChange:OCMOCK_ANY];
//        [[(id)self.mockExpirationTimer stub] objectsDidChange:OCMOCK_ANY];
//        // when
//        for(id<ZMContextChangeTracker> tracker in self.sut.contextChangeTrackers) {
//            [tracker objectsDidChange:[NSSet setWithObject:message]];
//        }
//
//        // then
//        ZMGenericMessage *mediumGenericMessage = [message.imageAssetStorage genericMessageForFormat:ZMImageFormatMedium];
//        ZMGenericMessage *previewGenericMessage = [message.imageAssetStorage genericMessageForFormat:ZMImageFormatPreview];
//
//        XCTAssertEqual(mediumGenericMessage.image.height, previewGenericMessage.image.originalHeight);
//        XCTAssertEqual(mediumGenericMessage.image.width, previewGenericMessage.image.originalWidth);
//    }];
//
//    WaitForAllGroupsToBeEmpty(0.5);
//}
//
//@end
//
//
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
//
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



//#import "MessagingTest.h"
//
//@class ZMMessageTranscoder;
//@class ZMUser;
//@class ZMUpstreamInsertedObjectSync;
//
//@interface ZMMessageTranscoderTests : MessagingTest {
//    ZMMessageTranscoder *_sut;
//}
//
//@property (nonatomic) ZMMessageTranscoder *sut;
//@property (nonatomic) ZMUser *user1;
//@property (nonatomic) ZMUser *selfUser;
//
//@property (nonatomic) ZMUpstreamInsertedObjectSync *upstreamObjectSync;
//
//@property (nonatomic) id notificationDispatcher;
//@property (nonatomic) id mockExpirationTimer;
//
//- (ZMConversation *)insertGroupConversation;
//- (ZMConversation *)insertGroupConversationInMoc:(NSManagedObjectContext *)moc;
//
//@end
//



//
//
//@import ZMTransport;
//@import ZMCMockTransport;
//@import Cryptobox;
//@import WireRequestStrategy;
//@import ZMCDataModel;
//
//#import "ZMMessageTranscoderTests.h"
//
//
//static NSString const *EventTypeMessageAdd = @"conversation.message-add";
//
//static NSString const *GetConversationURL = @"/conversations/%@/events?start=%@&end=%@";
//
//
//@implementation ZMMessageTranscoderTests
//
//- (void)setUp
//{
//    [super setUp];
//
//    self.mockExpirationTimer = [OCMockObject mockForClass:ZMMessageExpirationTimer.class];
//    self.upstreamObjectSync = [OCMockObject mockForClass:ZMUpstreamInsertedObjectSync.class];
//    self.notificationDispatcher =
//    [OCMockObject niceMockForProtocol:@protocol(ZMPushMessageHandler)];
//
//    [self verifyMockLater:self.upstreamObjectSync];
//    [self setupSelfConversation];
//}
//
//- (ZMMessageTranscoder *)sut
//{
//    if (!_sut) {
//        _sut = [ZMMessageTranscoder systemMessageTranscoderWithManagedObjectContext:self.syncMOC
//                                                        localNotificationDispatcher:self.notificationDispatcher];
//    }
//    return _sut;
//}
//
//- (void)tearDown
//{
//    [[self.mockExpirationTimer expect] tearDown];
//    [self.sut tearDown];
//    self.mockExpirationTimer = nil;
//    self.sut = nil;
//    self.upstreamObjectSync = nil;
//    [super tearDown];
//}
//
//- (void)setupSelfConversation
//{
//    self.selfUser = [ZMUser selfUserInContext:self.uiMOC];
//    self.selfUser.remoteIdentifier = [NSUUID createUUID];
//    ZMConversation *selfConversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
//    selfConversation.remoteIdentifier = self.selfUser.remoteIdentifier;
//    selfConversation.conversationType = ZMConversationTypeSelf;
//    [self.uiMOC saveOrRollback];
//}
//
//- (ZMConversation *)insertGroupConversationInMoc:(NSManagedObjectContext *)moc
//{
//    ZMUser *user1 = [ZMUser insertNewObjectInManagedObjectContext:moc];
//    user1.remoteIdentifier = [NSUUID createUUID];
//    self.user1 = user1;
//
//    ZMUser *user2 = [ZMUser insertNewObjectInManagedObjectContext:moc];
//    user2.remoteIdentifier = [NSUUID createUUID];
//
//    ZMUser *user3 = [ZMUser insertNewObjectInManagedObjectContext:moc];
//    user3.remoteIdentifier = [NSUUID createUUID];
//
//    ZMConversation *conversation = [ZMConversation insertGroupConversationIntoManagedObjectContext:moc withParticipants:@[user1, user2, user3]];
//    conversation.remoteIdentifier = [NSUUID createUUID];
//    return conversation;
//}
//
//- (ZMConversation *)insertGroupConversation
//{
//    ZMConversation *result = [self insertGroupConversationInMoc:self.syncMOC];
//    XCTAssertTrue([self.syncMOC saveOrRollback]);
//    return result;
//}
//
//
//- (void)testThatItIsCreatedWithSlowSyncComplete
//{
//    XCTAssertTrue(self.sut.isSlowSyncDone);
//}
//
//- (void)testThatItDoesNotNeedsSlowSyncEvenAfterSetNeedsSlowSync
//{
//    // when
//    [self.sut setNeedsSlowSync];
//
//    // then
//    XCTAssertTrue(self.sut.isSlowSyncDone);
//}
//
//
//
//@end
//

// MARK: - Helpers
extension ClientMessageTranscoderTests {
    
    func createUser() -> ZMUser {
        let user = ZMUser.insertNewObject(in: self.syncMOC)
        user.remoteIdentifier = UUID.create()
        return user
    }
    
    func createGroupConversation(with user: ZMUser) -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
        conversation.conversationType = .group
        conversation.remoteIdentifier = UUID.create()
        conversation.mutableOtherActiveParticipants.add(user)
        return conversation
    }
}


