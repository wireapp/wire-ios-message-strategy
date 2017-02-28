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


import XCTest
import ZMProtos
import ZMCDataModel
import ZMUtilities
@testable import WireMessageStrategy

class ClientMessageRequestFactoryTests: MessagingTestBase {
}

// MARK: - Text messages
extension ClientMessageRequestFactoryTests {

    func testThatItCreatesRequestToPostOTRTextMessage() {
        
        // GIVEN
        let text = "Antani"
        let message = self.groupConversation.appendMessage(withText: text) as! ZMClientMessage
        
        // WHEN
        guard let request = ClientMessageRequestFactory().upstreamRequestForMessage(message, forConversationWithId: self.groupConversation.remoteIdentifier!) else {
            return XCTFail("No request")
        }
        
        // THEN
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
        
        guard let receivedMessage = self.outgoingEncryptedMessage(from: request, for: self.otherClient) else {
            return XCTFail("Invalid message")
        }
        XCTAssertEqual(receivedMessage.textData?.content, text)
    }
}

// MARK: - Confirmation Messages
extension ClientMessageRequestFactoryTests {
    
    func testThatItCreatesRequestToPostOTRConfirmationMessage() {
        // GIVEN
        let text = "Antani"
        let message = self.oneToOneConversation.appendMessage(withText: text) as! ZMClientMessage
        message.sender = self.otherUser
        let confirmationMessage = message.confirmReception()!
        
        print("CLIENT ID", (message.conversation?.otherActiveParticipants.firstObject! as! ZMUser).remoteIdentifier!)
        print("OTHER USER", self.otherUser.remoteIdentifier!)
        // WHEN
        guard let request = ClientMessageRequestFactory().upstreamRequestForMessage(confirmationMessage, forConversationWithId: self.oneToOneConversation.remoteIdentifier!) else {
            return XCTFail("No request")
        }
        
        // THEN
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(self.oneToOneConversation.remoteIdentifier!.transportString())/otr/messages?report_missing=\(self.otherUser.remoteIdentifier!.transportString())")
        guard let receivedMessage = self.outgoingEncryptedMessage(from: request, for: self.otherClient) else {
            return XCTFail("Invalid message")
        }
        XCTAssertTrue(receivedMessage.hasConfirmation())
    }
}

// MARK: - Image
extension ClientMessageRequestFactoryTests {

    func testThatItCreatesRequestToPostOTRImageMessage() {
        for _ in [ZMImageFormat.medium, ZMImageFormat.preview] {
            // GIVEN
            let imageData = self.verySmallJPEGData()
            let format = ZMImageFormat.medium
            let message = self.createImageMessage(imageData: imageData, format: format, processed: true, stored: false, encrypted: true, ephemeral: false, moc: self.syncMOC)
            
            // WHEN
            let request = ClientMessageRequestFactory().upstreamRequestForAssetMessage(format, message: message)
            
            // THEN
            let expectedPath = "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets"

            assertRequest(request, forImageMessage: message, conversationId: self.groupConversation.remoteIdentifier!, encrypted: true, expectedPath: expectedPath, expectedPayload: nil, format: format)
            XCTAssertEqual(request?.multipartBodyItems()?.count, 2)
        }
    }
    
    func testThatItCreatesRequestToReuploadOTRImageMessage() {
        
        for _ in [ZMImageFormat.medium, ZMImageFormat.preview] {

            // GIVEN
            let imageData = self.verySmallJPEGData()
            let format = ZMImageFormat.medium
            let message = self.createImageMessage(imageData: imageData, format: format, processed: false, stored: false, encrypted: true, ephemeral: false, moc: self.syncMOC)
            message.assetId = UUID.create()
            
            // WHEN
            guard let request = ClientMessageRequestFactory().upstreamRequestForAssetMessage(format, message: message) else {
                return XCTFail()
            }
            
            // THEN
            let expectedPath = "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets/\(message.assetId!.transportString())"

            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
            XCTAssertEqual(request.path, expectedPath)
            XCTAssertNotNil(request.binaryData)
            XCTAssertEqual(request.shouldUseOnlyBackgroundSession, true)
        }
    }
}

// MARK: - File Upload

extension ClientMessageRequestFactoryTests {
    
    func testThatItCreatesRequestToUploadAFileMessage_Placeholder() {
        // GIVEN
        let (message, _, _) = self.createAssetFileMessage(false, encryptedDataOnDisk: false)
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.placeholder, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.binaryDataType, "application/x-protobuf")
        XCTAssertNotNil(request.binaryData)
    }
    
    func testThatItCreatesRequestToUploadAFileMessage_Placeholder_UploadedDataPresent() {
        // GIVEN
        let (message, _, _) = self.createAssetFileMessage(true, encryptedDataOnDisk: true)
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.placeholder, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.binaryDataType, "application/x-protobuf")
        XCTAssertNotNil(request.binaryData)
    }
    
    func testThatItCreatesRequestToUploadAFileMessage_FileData() {
        // GIVEN
        let (message, _, _) = self.createAssetFileMessage(true)
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
    }
    
    func testThatItCreatesRequestToReuploadFileMessageMetaData_WhenAssetIdIsPresent() {
        // GIVEN
        let (message, _, _) = self.createAssetFileMessage()
        message.assetId = UUID.create()
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets/\(message.assetId!.transportString())")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertNotNil(request.binaryData)
        XCTAssertEqual(request.binaryDataType, "application/x-protobuf")
    }
    
    func testThatTheRequestToReuploadAFileMessageDoesNotContainTheBinaryFileData() {
        // GIVEN
        let (message, _, nonce) = self.createAssetFileMessage()
        message.assetId = UUID.create()
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertNil(syncMOC.zm_fileAssetCache.accessRequestURL(nonce))
        XCTAssertNotNil(request.binaryData)
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets/\(message.assetId!.transportString())")
    }
    
    func testThatItDoesNotCreatesRequestToReuploadFileMessageMetaData_WhenAssetIdIsPresent_Placeholder() {
        // GIVEN
        let (message, _, _) = self.createAssetFileMessage()
        message.assetId = UUID.create()
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.placeholder, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertFalse(request.path.contains(message.assetId!.transportString()))
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
    }
    
    func testThatItWritesTheMultiPartRequestDataToDisk() {
        // GIVEN
        let (message, data, nonce) = self.createAssetFileMessage()
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message:message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        XCTAssertNotNil(uploadRequest)
        
        // THEN
        guard let url = syncMOC.zm_fileAssetCache.accessRequestURL(nonce) else { return XCTFail() }
        guard let multipartData = try? Data(contentsOf: url) else { return XCTFail() }
        let multiPartItems = (multipartData as NSData).multipartDataItemsSeparated(withBoundary: "frontier")
        XCTAssertEqual(multiPartItems.count, 2)
        let fileData = (multiPartItems.last as? ZMMultipartBodyItem)?.data
        XCTAssertEqual(data, fileData)
    }
    
    func testThatItSetsTheDataMD5() {
        // GIVEN
        let (message, data, nonce) = self.createAssetFileMessage(true)
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        XCTAssertNotNil(uploadRequest)
        
        // THEN
        guard let url = syncMOC.zm_fileAssetCache.accessRequestURL(nonce) else { return XCTFail() }
        guard let multipartData = try? Data(contentsOf: url) else { return XCTFail() }
        let multiPartItems = (multipartData as NSData).multipartDataItemsSeparated(withBoundary: "frontier")
        XCTAssertEqual(multiPartItems.count, 2)
        guard let fileData = (multiPartItems.last as? ZMMultipartBodyItem) else { return XCTFail() }
        XCTAssertEqual(fileData.headers?["Content-MD5"] as? String, data.zmMD5Digest().base64String())
    }
    
    func testThatItDoesNotCreateARequestIfTheMessageIsNotAFileAssetMessage_AssetClientMessage_Image() {
        // GIVEN
        let imageData = verySmallJPEGData()
        let message = self.createImageMessage(imageData: imageData,
                                              format: .medium,
                                              processed: true,
                                              stored: false,
                                              encrypted: true,
                                              ephemeral: false,
                                              moc: syncMOC)
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        XCTAssertNil(uploadRequest)
    }
    
    func testThatItReturnsNilWhenThereIsNoEncryptedDataToUploadOnDisk() {
        // GIVEN
        let (message, _, _) = self.createAssetFileMessage(encryptedDataOnDisk: false)
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        XCTAssertNil(uploadRequest)
    }
    
    func testThatItStoresTheUploadDataInTheCachesDirectoryAndMarksThemAsNotBeingBackedUp() {
        // GIVEN
        let (message, _, nonce) = self.createAssetFileMessage()
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // THEN
        XCTAssertNotNil(uploadRequest)
        guard let url = syncMOC.zm_fileAssetCache.accessRequestURL(nonce)
        else { return XCTFail() }
        
        // It's very likely that this is the most un-future proof way of testing this...
        guard let resourceValues = try? url.resourceValues(forKeys: Set(arrayLiteral: .isExcludedFromBackupKey)),
              let isExcludedFromBackup = resourceValues.isExcludedFromBackup
        else {return XCTFail()}
        XCTAssertTrue(isExcludedFromBackup)
    }
    
    func testThatItCreatesTheMultipartDataWithTheCorrectContentTypes() {
        // GIVEN
        let metaData = "metadata".data(using: String.Encoding.utf8)!
        let fileData = "filedata".data(using: String.Encoding.utf8)!
        
        // WHEN
        let multipartData = ClientMessageRequestFactory().dataForMultipartFileUploadRequest(metaData, fileData: fileData)
        
        // THEN
        guard let parts = (multipartData as NSData).multipartDataItemsSeparated(withBoundary: "frontier") as? [ZMMultipartBodyItem] else { return XCTFail() }
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts.first?.contentType, "application/x-protobuf")
        XCTAssertEqual(parts.last?.contentType, "application/octet-stream")
    }
}

// MARK: - Helpers
extension ClientMessageRequestFactoryTests {
    
    var testURL: URL {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let documentsURL = URL(fileURLWithPath: documents)
        return documentsURL.appendingPathComponent("file.dat")
    }
    
    func createAssetFileMessage(_ withUploaded: Bool = true,
                                encryptedDataOnDisk: Bool = true,
                                isEphemeral: Bool = false) -> (ZMAssetClientMessage, Data, UUID) {
        let data = createTestFile(testURL)
        let nonce = UUID.create()
        let metadata = ZMFileMetadata(fileURL: testURL)
        let message = ZMAssetClientMessage(
            fileMetadata: metadata,
            nonce: nonce,
            managedObjectContext: self.syncMOC,
            expiresAfter: isEphemeral ? 10 : 0
        )
        
        XCTAssertNotNil(data)
        XCTAssertNotNil(message)
        
        if withUploaded {
            let otrKey = Data.randomEncryptionKey()
            let sha256 = Data.randomEncryptionKey()
            let uploadedMessage = ZMGenericMessage.genericMessage(withUploadedOTRKey: otrKey, sha256: sha256, messageID: nonce.transportString(), expiresAfter: isEphemeral ? NSNumber(value: 10) : nil)
            XCTAssertNotNil(uploadedMessage)
            message.add(uploadedMessage)
        }
        
        if encryptedDataOnDisk {
            self.syncMOC.zm_fileAssetCache.storeAssetData(nonce, fileName: name!, encrypted: true, data: data)
        }
        
        message.visibleInConversation = self.groupConversation
        return (message, data, nonce)
    }
    
    func createTestFile(_ url: URL) -> Data {
        let data: Data! = name!.data(using: String.Encoding.utf8)
        try! data.write(to: url, options: [])
        return data
    }
    
    func assertRequest(_ request: ZMTransportRequest?, forImageMessage message: ZMAssetClientMessage, conversationId: UUID, encrypted: Bool, expectedPath: String, expectedPayload: [String: NSObject]?, format: ZMImageFormat)
    {
        let imageData = message.imageAssetStorage!.imageData(for: format, encrypted: encrypted)!
        guard let request = request else {
            return XCTFail("ClientRequestFactory should create requet to post medium asset message")
        }
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, expectedPath)
        
        guard let multipartItems = request.multipartBodyItems() as? [AnyObject] else {
            return XCTFail("Request should be multipart data request")
        }
        
        XCTAssertEqual(multipartItems.count, 2)
        guard let imageDataItem = multipartItems.last else {
            return XCTFail("Request should contain image multipart data")
        }
        XCTAssertEqual(imageDataItem.data, imageData)
        
        
        guard let metaDataItem = multipartItems.first else {
            return XCTFail("Request should contain metadata multipart data")
        }
        
        let metaData : [String: NSObject]
        do {
            metaData = try JSONSerialization.jsonObject(with: (metaDataItem as AnyObject).data, options: JSONSerialization.ReadingOptions()) as! [String : NSObject]
        }
        catch {
            metaData = [:]
        }
        if let expectedPayload = expectedPayload {
            XCTAssertEqual(metaData, expectedPayload)
        }

    }
}

// MARK: Ephemeral Messages 
extension ClientMessageRequestFactoryTests {

    
    func testThatItCreatesRequestToPostEphemeralTextMessage() {
        // GIVEN
        let text = "Boo"
        self.groupConversation.messageDestructionTimeout = 10
        let message = self.groupConversation.appendMessage(withText: text) as! ZMClientMessage
        
        // WHEN
        guard let request = ClientMessageRequestFactory().upstreamRequestForMessage(message, forConversationWithId: self.groupConversation.remoteIdentifier!) else {
            return XCTFail()
        }
        
        // THEN
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages?report_missing=\(self.otherUser.remoteIdentifier!.transportString())")
        guard let receivedMessage = self.outgoingEncryptedMessage(from: request, for: self.otherClient) else {
            return XCTFail("Invalid message")
        }
        XCTAssertEqual(receivedMessage.textData?.content, text)
    }
    
    func testThatItCreatesRequestToUploadAnEphemeralFileMessage_FileData() {
        
        // GIVEN
        let (message, _, _) = self.createAssetFileMessage(true, isEphemeral: true)
        
        // WHEN
        let sut = ClientMessageRequestFactory()
        guard let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!) else {
            return XCTFail()
        }
        
        // then
        XCTAssertEqual(uploadRequest.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets?report_missing=\(self.otherUser.remoteIdentifier!.transportString())")
        XCTAssertEqual(uploadRequest.method, ZMTransportRequestMethod.methodPOST)
    }
    

    func testThatItCreatesRequestToPostEphemeralImageMessage() {
        for _ in [ZMImageFormat.medium, ZMImageFormat.preview] {

            // GIVEN
            let imageData = self.verySmallJPEGData()
            let format = ZMImageFormat.medium
            
            let message = self.createImageMessage(imageData: imageData,
                                                  format: format,
                                                  processed: true,
                                                  stored: false,
                                                  encrypted: true,
                                                  ephemeral: true,
                                                  moc: self.syncMOC)
            
            // WHEN
            let request = ClientMessageRequestFactory().upstreamRequestForAssetMessage(format, message: message)
            
            // THEN
            let expectedPath = "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets?report_missing=\(self.otherUser.remoteIdentifier!.transportString())"
            
            assertRequest(request, forImageMessage: message, conversationId: self.groupConversation.remoteIdentifier!, encrypted: true, expectedPath: expectedPath, expectedPayload: nil, format: format)
            XCTAssertEqual(request?.multipartBodyItems()?.count, 2)
        }
    }
}

extension ClientMessageRequestFactoryTests {
    
    func createImageMessage(imageData: Data,
                            format: ZMImageFormat,
                            processed: Bool,
                            stored: Bool,
                            encrypted: Bool,
                            ephemeral: Bool,
                            moc: NSManagedObjectContext) -> ZMAssetClientMessage {
        let nonce = UUID.create()
        let imageMessage = ZMAssetClientMessage(originalImageData: imageData, nonce: nonce, managedObjectContext: moc, expiresAfter: ephemeral ? 10 : 0)
        imageMessage.isEncrypted = encrypted
        if processed {
            let imageSize = ZMImagePreprocessor.sizeOfPrerotatedImage(with: imageData)
            let properties = ZMIImageProperties(size: imageSize, length: UInt(imageData.count), mimeType: "image/jpeg")
            var keys: ZMImageAssetEncryptionKeys?
            if encrypted {
                keys = ZMImageAssetEncryptionKeys.init(otrKey: Data.zmRandomSHA256Key(), macKey: Data.zmRandomSHA256Key(), mac: Data.zmRandomSHA256Key())
            }
            let message = ZMGenericMessage.genericMessage(mediumImageProperties: properties, processedImageProperties: properties, encryptionKeys: keys, nonce: nonce.transportString(), format: format, expiresAfter: ephemeral ? 10 : nil)
            imageMessage.add(message)
            
            let directory = self.uiMOC.zm_imageAssetCache
            if stored {
                directory?.storeAssetData(nonce, format: .original, encrypted: false, data: imageData)
            }
            if processed {
                directory?.storeAssetData(nonce, format: format, encrypted: false, data: imageData)
            }
            if encrypted {
                directory?.storeAssetData(nonce, format: format, encrypted: true, data: imageData)
            }
        }
        imageMessage.visibleInConversation = self.groupConversation
        return imageMessage
    }
}

