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
import ZMCMockTransport

class ClientMessageTranscoderTests: MessagingTest {

    var clientRegistrationStatus: MockClientRegistrationStatus!
    var localNotificationDispatcher: MockPushMessageHandler!
    var confirmationStatus: MockConfirmationStatus!
    var sut: ClientMessageTranscoder!
    var groupConversation: ZMConversation!
    var oneToOneConversation: ZMConversation!
    var selfClient: UserClient!
    var otherUser: ZMUser!
    var otherClient: UserClient!
    var otherEncryptionContext: EncryptionContext!
    
    override func setUp() {
        super.setUp()
        self.localNotificationDispatcher = MockPushMessageHandler()
        self.clientRegistrationStatus = MockClientRegistrationStatus()
        self.confirmationStatus = MockConfirmationStatus()
        
        self.setupUsersAndClients()
        self.groupConversation = self.createGroupConversation(with: self.otherUser)
        self.oneToOneConversation = self.setupOneToOneConversation(with: self.otherUser)
        
        self.sut = ClientMessageTranscoder(in: self.syncMOC, localNotificationDispatcher: self.localNotificationDispatcher, clientRegistrationStatus: self.clientRegistrationStatus, apnsConfirmationStatus: self.confirmationStatus)
        
        self.syncMOC.saveOrRollback()
    }
    
    override func tearDown() {
        self.localNotificationDispatcher = nil
        self.clientRegistrationStatus = nil
        self.confirmationStatus = nil
        self.otherUser = nil
        self.otherClient = nil
        self.selfClient = nil
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


// MARK: - Processing events

extension ClientMessageTranscoderTests {

    func testThatANewOtrMessageIsCreatedFromAnEvent() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let text = "Everything"
            let base64Text = "CiQ5ZTU2NTQwOS0xODZiLTRlN2YtYTE4NC05NzE4MGE0MDAwMDQSDAoKRXZlcnl0aGluZw=="
            let payload = [
                "recipient": self.selfClient.remoteIdentifier,
                "sender": self.otherClient.remoteIdentifier,
                "text": base64Text
            ]
            let eventPayload = [
                "type": "conversation.otr-message-add",
                "data": payload,
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
    
    func testThatANewOtrMessageIsCreatedFromADecryptedAPNSEvent() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let text = "Everything"
            let event = self.decryptedUpdateEventFromOtherClient(text: text)
            
            // WHEN
            self.sut.processEvents([event], liveEvents: false, prefetchResult: nil)
            
            // THEN
            XCTAssertEqual((self.groupConversation.messages.lastObject as? ZMClientMessage)?.textMessageData?.messageText, text)
        }
    }
    
}

// MARK: - Request generation

extension ClientMessageTranscoderTests {
    
    func testThatItGeneratesARequestToSendAClientMessage() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let text = "Lorem ipsum"
            let message = self.groupConversation.appendMessage(withText: text) as! ZMClientMessage
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
            
            // check sender/receiver
            guard let protobuf = ZMNewOtrMessage.parse(from: request.binaryData) else { return XCTFail() }
            let userEntries = protobuf.recipients.flatMap({ $0 })
            XCTAssertEqual(userEntries.count, 1)
            let clientEntries = userEntries.first?.clients.flatMap({ $0 }) ?? []
            XCTAssertEqual(clientEntries.count, 1)
            let clientID = clientEntries.first?.client
            XCTAssertEqual(clientID, self.otherClient.clientId)
            
            // text content
            guard let cyphertext = clientEntries.first?.text else { return XCTFail("no encrypted data") }
            guard let plaintext = self.decryptMessageFromSelf(cypherText: cyphertext, to: self.otherClient) else {
                return XCTFail("failed to decrypt")
            }
            guard let receivedMessage = ZMGenericMessage.parse(from: plaintext) else { return XCTFail("Invalid message") }
            XCTAssertEqual(receivedMessage.textData?.content, text)
        }
    }
    
    func testThatItGeneratesARequestToSendAClientMessageExternalWithExternalBlob() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // GIVEN
            let text = String(repeating: "Hi", count: 100000)
            let message = self.groupConversation.appendMessage(withText: text) as! ZMClientMessage
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
            
            // check sender/receiver
            guard let protobuf = ZMNewOtrMessage.parse(from: request.binaryData) else { return XCTFail() }
            let userEntries = protobuf.recipients.flatMap({ $0 })
            XCTAssertEqual(userEntries.count, 1)
            let clientEntries = userEntries.first?.clients.flatMap({ $0 }) ?? []
            XCTAssertEqual(clientEntries.count, 1)
            let clientID = clientEntries.first?.client
            XCTAssertEqual(clientID, self.otherClient.clientId)
            
            // text content
            guard let cyphertext = clientEntries.first?.text else { return XCTFail("no encrypted data") }
            guard let plaintext = self.decryptMessageFromSelf(cypherText: cyphertext, to: self.otherClient) else {
                return XCTFail("failed to decrypt")
            }
            guard let receivedMessage = ZMGenericMessage.parse(from: plaintext) else { return XCTFail("Invalid message") }
            XCTAssertTrue(receivedMessage.hasExternal())
            guard let key = receivedMessage.external.otrKey,
                let sha = receivedMessage.external.sha256 else { return XCTFail("No external key/sha") }
            XCTAssertTrue(protobuf.hasBlob())
            guard let blob = protobuf.blob else { return XCTFail("No blob") }
            XCTAssertEqual(blob.zmSHA256Digest(), sha)
            guard let decryptedBlob = blob.zmDecryptPrefixedPlainTextIV(key: key) else { return XCTFail("Failed to decrypt blob") }
            let externalMessage = ZMGenericMessage.parse(from: decryptedBlob)
            XCTAssertTrue(externalMessage?.textData?.content == text) // here I use == instead of XCTAssertEqual because the 
                // warning generated by a failed comparison of a 200000-chars string almost freezes XCode
        }
    }
}

// MARK: - Generic Message
extension ClientMessageTranscoderTests {
    
}

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
    
    /// Creates an encryption context in a temp folder and creates keys
    func setupUsersAndClients() {
        
        // user
        self.otherUser = self.createUser()
        self.selfClient = self.createSelfClient()
        
        // other client
        self.otherClient = UserClient.insertNewObject(in: self.syncMOC)
        self.otherClient.remoteIdentifier = "aabbccdd"
        self.otherClient.user = self.otherUser
        self.syncMOC.saveOrRollback()
        
        self.establishSessionFromSelf(to: self.otherClient)
    }
    
    /// Creates an update event with encrypted message from the other client, decrypts it and returns it
    func decryptedUpdateEventFromOtherClient(text: String) -> ZMUpdateEvent {
        
        let message = ZMGenericMessage.message(text: text, nonce: UUID.create().transportString())
        let cyphertext = self.encryptedMessageToSelf(message: message, from: self.otherClient)
        let payload = ["recipient": self.selfClient.remoteIdentifier!,
                       "sender": self.otherClient.remoteIdentifier!,
                       "text": cyphertext.base64String()
        ]
        let event = ZMUpdateEvent(fromEventStreamPayload: [
            "type": "conversation.otr-message-add",
            "from": self.otherUser.remoteIdentifier!.transportString(),
            "data": payload,
            "conversation": self.groupConversation.remoteIdentifier!.transportString(),
            "time": Date().transportString()
            ] as NSDictionary, uuid: nil)
        
        var decryptedEvent: ZMUpdateEvent?
        self.selfClient.keysStore.encryptionContext.perform { session in
            decryptedEvent = session.decryptAndAddClient(event!, in: self.syncMOC)
        }
        return decryptedEvent!
    }
    
    /// Makes a conversation secure
    func set(conversation: ZMConversation, securityLevel: ZMConversationSecurityLevel) {
        conversation.setValue(NSNumber(value: securityLevel.rawValue), forKey: #keyPath(ZMConversation.securityLevel))
        if conversation.securityLevel != securityLevel {
            fatalError()
        }
    }
}



