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
        //given
        let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage
        
        //when
        let request = ClientMessageRequestFactory().upstreamRequestForMessage(message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        //then
        XCTAssertEqual(request?.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request?.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
        XCTAssertEqual(message.encryptedMessagePayloadDataOnly, request?.binaryData)
    }
}

// MARK: - Confirmation Messages
extension ClientMessageRequestFactoryTests {
    
    func testThatItCreatesRequestToPostOTRConfirmationMessage() {
        //given
        let message = self.oneToOneConversation.appendMessage(withText: "Foobar") as! ZMClientMessage
        let confirmationMessage = message.confirmReception()!
        
        //when
        let request = ClientMessageRequestFactory().upstreamRequestForMessage(confirmationMessage, forConversationWithId: self.oneToOneConversation.remoteIdentifier!)
        
        //then
        XCTAssertEqual(request?.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request?.path, "/conversations/\(self.oneToOneConversation.remoteIdentifier!.transportString())/otr/messages?report_missing=\(self.otherUser.remoteIdentifier!.transportString())")
        XCTAssertNotNil(request?.binaryData)
    }
}

// MARK: - Image
extension ClientMessageRequestFactoryTests {

    func testThatItCreatesRequestToPostOTRImageMessage() {
        for _ in [ZMImageFormat.medium, ZMImageFormat.preview] {
            //given
            let imageData = self.verySmallJPEGData()
            let format = ZMImageFormat.medium
            let message = self.createImageMessage(imageData: imageData, format: format, processed: true, stored: false, encrypted: true, ephemeral: false, moc: self.syncMOC)
            message.visibleInConversation = self.groupConversation
            
            //when
            let request = ClientMessageRequestFactory().upstreamRequestForAssetMessage(format, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
            
            //then
            let expectedPath = "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets"

            assertRequest(request, forImageMessage: message, conversationId: self.groupConversation.remoteIdentifier!, encrypted: true, expectedPath: expectedPath, expectedPayload: nil, format: format)
            XCTAssertEqual(request?.multipartBodyItems()?.count, 2)
        }
    }
    
    func testThatItCreatesRequestToReuploadOTRImageMessage() {
        
        for _ in [ZMImageFormat.medium, ZMImageFormat.preview] {

            // given
            let imageData = self.verySmallJPEGData()
            let format = ZMImageFormat.medium
            let message = self.createImageMessage(imageData: imageData, format: format, processed: false, stored: false, encrypted: true, ephemeral: false, moc: self.syncMOC)
            message.assetId = UUID.create()
            message.visibleInConversation = self.groupConversation
            
            //when
            let request = ClientMessageRequestFactory().upstreamRequestForAssetMessage(format, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
            
            //then
            let expectedPath = "/conversations/\(self.groupConversation.remoteIdentifier!)/otr/assets/\(message.assetId!.transportString())"

            XCTAssertEqual(request?.method, ZMTransportRequestMethod.methodPOST)
            XCTAssertEqual(request?.path, expectedPath)
            XCTAssertNotNil(request?.binaryData)
            XCTAssertEqual(request?.shouldUseOnlyBackgroundSession, true)
        }
    }
}

// MARK: - File Upload

extension ClientMessageRequestFactoryTests {
    
    func testThatItCreatesRequestToUploadAFileMessage_Placeholder() {
        // given
        let (message, _, _) = createAssetFileMessage(false, encryptedDataOnDisk: false)
        message.visibleInConversation = self.groupConversation
        
        // when
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
        // given
        let (message, _, _) = createAssetFileMessage(true, encryptedDataOnDisk: true)
        message.visibleInConversation = self.groupConversation
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.placeholder, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.binaryDataType, "application/x-protobuf")
        XCTAssertNotNil(request.binaryData)
    }
    
    func testThatItCreatesRequestToUploadAFileMessage_FileData() {
        // given
        let (message, _, _) = createAssetFileMessage(true)
        message.visibleInConversation = self.groupConversation

        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
    }
    
    func testThatItCreatesRequestToReuploadFileMessageMetaData_WhenAssetIdIsPresent() {
        // given
        let (message, _, _) = createAssetFileMessage()
        message.visibleInConversation = self.groupConversation
        message.assetId = UUID.create()
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets/\(message.assetId!.transportString())")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertNotNil(request.binaryData)
        XCTAssertEqual(request.binaryDataType, "application/x-protobuf")
    }
    
    func testThatTheRequestToReuploadAFileMessageDoesNotContainTheBinaryFileData() {
        // given
        let (message, _, nonce) = createAssetFileMessage()
        message.visibleInConversation = self.groupConversation
        message.assetId = UUID.create()
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertNil(syncMOC.zm_fileAssetCache.accessRequestURL(nonce))
        XCTAssertNotNil(request.binaryData)
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets/\(message.assetId!.transportString())")
    }
    
    func testThatItDoesNotCreatesRequestToReuploadFileMessageMetaData_WhenAssetIdIsPresent_Placeholder() {
        // given
        let (message, _, _) = createAssetFileMessage()
        message.assetId = UUID.create()
        message.visibleInConversation = self.groupConversation
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.placeholder, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertFalse(request.path.contains(message.assetId!.transportString()))
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
    }
    
    func testThatItWritesTheMultiPartRequestDataToDisk() {
        // given
        let (message, data, nonce) = createAssetFileMessage()
        message.visibleInConversation = self.groupConversation
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message:message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        XCTAssertNotNil(uploadRequest)
        
        // then
        guard let url = syncMOC.zm_fileAssetCache.accessRequestURL(nonce) else { return XCTFail() }
        guard let multipartData = try? Data(contentsOf: url) else { return XCTFail() }
        let multiPartItems = (multipartData as NSData).multipartDataItemsSeparated(withBoundary: "frontier")
        XCTAssertEqual(multiPartItems.count, 2)
        let fileData = (multiPartItems.last as? ZMMultipartBodyItem)?.data
        XCTAssertEqual(data, fileData)
    }
    
    func testThatItSetsTheDataMD5() {
        // given
        let (message, data, nonce) = createAssetFileMessage(true)
        message.visibleInConversation = self.groupConversation
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        XCTAssertNotNil(uploadRequest)
        
        // then
        guard let url = syncMOC.zm_fileAssetCache.accessRequestURL(nonce) else { return XCTFail() }
        guard let multipartData = try? Data(contentsOf: url) else { return XCTFail() }
        let multiPartItems = (multipartData as NSData).multipartDataItemsSeparated(withBoundary: "frontier")
        XCTAssertEqual(multiPartItems.count, 2)
        guard let fileData = (multiPartItems.last as? ZMMultipartBodyItem) else { return XCTFail() }
        XCTAssertEqual(fileData.headers?["Content-MD5"] as? String, data.zmMD5Digest().base64String())
    }
    
    func testThatItDoesNotCreateARequestIfTheMessageIsNotAFileAssetMessage_AssetClientMessage_Image() {
        // given
        let imageData = verySmallJPEGData()
        let message = createImageMessage(imageData: imageData, format: .medium, processed: true, stored: false, encrypted: true, ephemeral: false, moc: syncMOC)
        message.visibleInConversation = self.groupConversation
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        XCTAssertNil(uploadRequest)
    }
    
    func testThatItReturnsNilWhenThereIsNoEncryptedDataToUploadOnDisk() {
        // given
        let (message, _, _) = createAssetFileMessage(encryptedDataOnDisk: false)
        message.visibleInConversation = self.groupConversation
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        XCTAssertNil(uploadRequest)
    }
    
    func testThatItStoresTheUploadDataInTheCachesDirectoryAndMarksThemAsNotBeingBackedUp() {
        // given
        let (message, _, nonce) = createAssetFileMessage()
        message.visibleInConversation = self.groupConversation
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
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
        // given
        let metaData = "metadata".data(using: String.Encoding.utf8)!
        let fileData = "filedata".data(using: String.Encoding.utf8)!
        
        // when
        let multipartData = ClientMessageRequestFactory().dataForMultipartFileUploadRequest(metaData, fileData: fileData)
        
        // then
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
    
    func createAssetFileMessage(_ withUploaded: Bool = true, encryptedDataOnDisk: Bool = true, isEphemeral: Bool = false) -> (ZMAssetClientMessage, Data, UUID) {
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
        //given
        self.groupConversation.messageDestructionTimeout = 10
        let message = self.groupConversation.appendMessage(withText: "foo") as! ZMClientMessage
        
        //when
        let request = ClientMessageRequestFactory().upstreamRequestForMessage(message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        //then
        XCTAssertEqual(request?.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request?.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages?report_missing=\(self.otherUser.remoteIdentifier!.transportString())")
        XCTAssertEqual(message.encryptedMessagePayloadDataOnly, request?.binaryData)
    }
    
    func testThatItCreatesRequestToUploadAnEphemeralFileMessage_FileData() {
        
        // given
        let (message, _, _) = createAssetFileMessage(true, isEphemeral: true)
        
        // when
        let sut = ClientMessageRequestFactory()
        let uploadRequest = sut.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
        
        // then
        guard let request = uploadRequest else { return XCTFail() }
        XCTAssertEqual(request.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets?report_missing=\(self.otherUser.remoteIdentifier!.transportString())")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
    }
    

    func testThatItCreatesRequestToPostEphemeralImageMessage() {
        for _ in [ZMImageFormat.medium, ZMImageFormat.preview] {

            //given
            let imageData = self.verySmallJPEGData()
            let format = ZMImageFormat.medium
            
            let message = self.createImageMessage(imageData: imageData, format: format, processed: true, stored: false, encrypted: true, ephemeral: true, moc: self.syncMOC)
            message.visibleInConversation = self.groupConversation
            
            //when
            let request = ClientMessageRequestFactory().upstreamRequestForAssetMessage(format, message: message, forConversationWithId: self.groupConversation.remoteIdentifier!)
            
            //then
            let expectedPath = "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/assets?report_missing=\(self.otherUser.remoteIdentifier!.transportString())"
            
            assertRequest(request, forImageMessage: message, conversationId: self.groupConversation.remoteIdentifier!, encrypted: true, expectedPath: expectedPath, expectedPayload: nil, format: format)
            XCTAssertEqual(request?.multipartBodyItems()?.count, 2)
        }
    }
}

extension ClientMessageRequestFactoryTests {
    
    func createImageMessage(imageData: Data, format: ZMImageFormat, processed: Bool, stored: Bool, encrypted: Bool, ephemeral: Bool, moc: NSManagedObjectContext) -> ZMAssetClientMessage {
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
        return imageMessage
    }
}

