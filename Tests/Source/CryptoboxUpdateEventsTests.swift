//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
@testable import WireMessageStrategy

class CryptoboxUpdateEventsTests : MessagingTest {
    
    func testThatItCanDecryptOTRMessageAddEvent() {
        
        // GIVEN
        let notificationID = UUID.create()
        let selfUser = ZMUser.selfUser(in: self.syncMOC)
        let selfClient = self.createSelfClient()
        
        let message = ZMGenericMessage.message(text: self.name!, nonce: UUID.create().transportString(), expiresAfter: nil)
        let encryptedData = self.encrypted(message: message, recipient: selfClient)
        
        let payload : NSDictionary = [
            "recipient" : selfClient.remoteIdentifier!,
            "sender" : selfClient.remoteIdentifier!,
            "text" : encryptedData.base64String()
        ]
        
        let streamPayload = self.eventStreamPayload(sender: selfUser, internalPayload: payload as! [String:Any], type: "conversation.otr-message-add")
        let event = ZMUpdateEvent(fromEventStreamPayload: streamPayload as NSDictionary, uuid: notificationID)
        
        // WHEN
        var maybeDecryptedEvent : ZMUpdateEvent?
        self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { (directory) in
            maybeDecryptedEvent = directory.decryptUpdateEventAndAddClient(event, managedObjectContext: self.syncMOC)
        }
        
        guard let decryptedEvent = maybeDecryptedEvent else {
            XCTFail()
            return
        }
        
        // THEN
        let dataDictionary = decryptedEvent.payload["data"] as? NSDictionary
        XCTAssertNotNil(dataDictionary)
        XCTAssertEqual(dataDictionary?["sender"] as? String, selfClient.remoteIdentifier!)
        XCTAssertEqual(dataDictionary?["recipient"] as? String, selfClient.remoteIdentifier!)
        let decryptedMessage = ZMClientMessage.messageUpdateResult(from: decryptedEvent, in: self.syncMOC, prefetchResult: nil).message as? ZMClientMessage
        XCTAssertEqual(decryptedMessage?.nonce.transportString(), message.messageId)
        XCTAssertEqual(decryptedMessage?.textMessageData?.messageText, message.text.content)
        XCTAssertEqual(decryptedEvent.uuid, notificationID)
    }
    
    func testThatItCanDecryptOTRAssetAddEvent() {
        
        // GIVEN
        let notificationID = UUID.create()
        let selfUser = ZMUser.selfUser(in: self.syncMOC)
        let selfClient = self.createSelfClient()
        
        let imageData = self.verySmallJPEGData()
        let imageSize = ZMImagePreprocessor.sizeOfPrerotatedImage(with: imageData)
        let properties = ZMIImageProperties(size: imageSize, length: UInt(imageData.count), mimeType: "image/jpeg")
        let keys = ZMImageAssetEncryptionKeys(otrKey: Data.randomEncryptionKey(), sha256: imageData.zmSHA256Digest())
        
        let messageNonce = UUID.create()
        
        let message = ZMGenericMessage.genericMessage(mediumImageProperties: properties,
                                                      processedImageProperties: properties,
                                                      encryptionKeys: keys,
                                                      nonce: messageNonce.transportString(),
                                                      format: .medium)
        let encryptedData = self.encrypted(message: message, recipient: selfClient)
        let payload = ["recipient" : selfClient.remoteIdentifier!,
                       "sender" : UUID.create().transportString(),
                       "id" : UUID.create().transportString(),
                       "key" : encryptedData.base64String()
        ] as [String: Any]
        let streamPayload = self.eventStreamPayload(sender: selfUser, internalPayload: payload, type: "conversation.otr-asset-add")
        let event = ZMUpdateEvent(fromEventStreamPayload: streamPayload as NSDictionary, uuid: notificationID)!
        
        // WHEN
        var maybeDecryptedEvent : ZMUpdateEvent?
        self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { (directory) in
            maybeDecryptedEvent = directory.decryptUpdateEventAndAddClient(event, managedObjectContext: self.syncMOC)
        }
        
        // THEN
        guard let decryptedEvent = maybeDecryptedEvent else {
            XCTFail()
            return
        }
        XCTAssertNotNil(decryptedEvent.payload["data"])
        let decryptedMessage = ZMAssetClientMessage.messageUpdateResult(from: decryptedEvent, in: self.syncMOC, prefetchResult: nil).message as! ZMAssetClientMessage
        XCTAssertEqual(decryptedMessage.nonce.transportString(), message.messageId)
        XCTAssertEqual(decryptedMessage.imageAssetStorage?.mediumGenericMessage, message)
        XCTAssertEqual(decryptedEvent.uuid, notificationID)
    }
    
    func testThatItInsertsAUnableToDecryptMessageIfItCanNotEstablishASession() {
        
        // GIVEN
        let notificationID = UUID.create()
        let selfUser = ZMUser.selfUser(in: self.syncMOC)
        let selfClient = self.createSelfClient()
        let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
        conversation.remoteIdentifier = UUID.create()
        conversation.conversationType = .group
        
        // create encrypted message
        let messageNonce = UUID.create()
        let message = ZMGenericMessage.message(text: "text", nonce: messageNonce.transportString())
        
        let payload = ["recipient" : selfClient.remoteIdentifier!,
                       "sender" : UUID.create().transportString(),
                       "id" : UUID.create().transportString(),
                       "key" : message.data().base64String() // wrong message content
        ] as [String: Any]
        let streamPayload = self.eventStreamPayload(sender: selfUser,
                                                    internalPayload: payload,
                                                    type: "conversation.otr-asset-add",
                                                    conversationID: conversation.remoteIdentifier!)
        
        let updateEvent = ZMUpdateEvent(fromEventStreamPayload: streamPayload as NSDictionary, uuid: notificationID)!
        
        // WHEN
        var maybeDecryptedEvent : ZMUpdateEvent?
        self.performIgnoringZMLogError {
            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { (directory) in
                maybeDecryptedEvent = directory.decryptUpdateEventAndAddClient(updateEvent, managedObjectContext: self.syncMOC)
            }
        }
        
        // THEN
        XCTAssertNil(maybeDecryptedEvent)
        let lastMessage = conversation.messages.lastObject as? ZMSystemMessage
        XCTAssertNotNil(lastMessage)
        XCTAssertEqual(lastMessage?.systemMessageType, ZMSystemMessageType.decryptionFailed)
    }
    
    func testThatItCanDecryptOTRMessageAddEventWithExternalData() {
    
        // GIVEN
        let notificationID = UUID.create()
        let selfUser = ZMUser.selfUser(in: self.syncMOC)
        let selfClient = self.createSelfClient()
        
        // create symmetrically encrypted text message and encrypt external message holding the keys using cryptobox
        let textMessage = ZMGenericMessage.message(text: self.name!, nonce: UUID.create().transportString())
        let dataWithKeys = ZMGenericMessage.encryptedDataWithKeys(from: textMessage)!
        
        let externalMessage = ZMGenericMessage.genericMessage(withKeyWithChecksum: dataWithKeys.keys, messageID: UUID.create().transportString())
        let encryptedData = self.encrypted(message: externalMessage, recipient: selfClient)
        
        // create encrypted update event
        let payload = ["recipient" : selfClient.remoteIdentifier!,
                       "sender" : selfClient.remoteIdentifier!,
                       "text" : encryptedData.base64String(),
                       "data" : dataWithKeys.data.base64String()
            ] as [String: Any]
        
        let streamPayload = self.eventStreamPayload(sender: selfUser, internalPayload: payload, type: "conversation.otr-message-add")
        let event = ZMUpdateEvent(fromEventStreamPayload: streamPayload as NSDictionary, uuid: notificationID)!
        
        // WHEN
        var maybeDecryptedEvent : ZMUpdateEvent?
        self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { (directory) in
            maybeDecryptedEvent = directory.decryptUpdateEventAndAddClient(event, managedObjectContext: self.syncMOC)
        }
        
        // THEN
        guard let decryptedEvent = maybeDecryptedEvent else {
            XCTFail()
            return
        }
        print(decryptedEvent.payload)
        let externalData = decryptedEvent.payload["external"]!
        let text = decryptedEvent.payload["data"]!
        
        XCTAssertTrue(decryptedEvent.isEncrypted)
        XCTAssertTrue(decryptedEvent.wasDecrypted)
        XCTAssertNotNil(externalData)
        XCTAssertNotNil(text)
        
        // WHEN
        let  maybeDecryptedMessage = ZMClientMessage.messageUpdateResult(from: decryptedEvent, in: self.syncMOC, prefetchResult: nil).message as? ZMClientMessage
        
        // THEN
        guard let decryptedMessage = maybeDecryptedMessage else {
            XCTFail()
            return
        }
        
        XCTAssertFalse(decryptedMessage.genericMessage!.hasExternal())
        XCTAssertEqual(decryptedMessage.nonce.transportString(), textMessage.messageId)
        XCTAssertEqual(decryptedEvent.uuid, notificationID)
    }

}

// MARK: - Helpers
extension CryptoboxUpdateEventsTests {
    
    func eventStreamPayload(sender: ZMUser, internalPayload: [String:Any], type: String, conversationID: UUID? = nil) -> [String:Any] {
        return [
            "time" : Date().transportString(),
            "data" : internalPayload,
            "conversation" : (conversationID ?? UUID.create()).transportString(),
            "from" : sender.remoteIdentifier!.transportString(),
            "type" : type
        ]
    }
}
