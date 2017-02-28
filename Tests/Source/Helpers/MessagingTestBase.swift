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

import ZMCDataModel
import ZMTesting
import Cryptobox

class MessagingTestBase: ZMTBaseTest {
    
    fileprivate(set) var syncMOC: NSManagedObjectContext!
    fileprivate(set) var uiMOC: NSManagedObjectContext!
    
    fileprivate(set) var groupConversation: ZMConversation!
    fileprivate(set) var oneToOneConversation: ZMConversation!
    fileprivate(set) var selfClient: UserClient!
    fileprivate(set) var otherUser: ZMUser!
    fileprivate(set) var otherClient: UserClient!
    fileprivate(set) var otherEncryptionContext: EncryptionContext!
    
    override func setUp() {
        super.setUp()
        
        self.deleteAllOtherEncryptionContexts()
        self.deleteAllFilesInCache()
        self.setupManagedObjectContexes()
        
        self.syncMOC.zm_cryptKeyStore.deleteAndCreateNewBox()
        
        self.setupUsersAndClients()
        self.groupConversation = self.createGroupConversation(with: self.otherUser)
        self.oneToOneConversation = self.setupOneToOneConversation(with: self.otherUser)
        
        self.syncMOC.saveOrRollback()
    }
    
    override func tearDown() {

        _ = self.waitForAllGroupsToBeEmpty(withTimeout: 10)
        
        self.otherUser = nil
        self.otherClient = nil
        self.selfClient = nil
        self.groupConversation = nil

        self.stopEphemeralMessageTimers()
        self.tearDownManagedObjectContexes()
        self.deleteAllFilesInCache()
        self.deleteAllOtherEncryptionContexts()
        
        super.tearDown()
    }
}

// MARK: - Messages 
extension MessagingTestBase {
    
    /// Creates an update event with encrypted message from the other client, decrypts it and returns it
    func decryptedUpdateEventFromOtherClient(text: String,
                                             conversation: ZMConversation? = nil,
                                             source: ZMUpdateEventSource = .pushNotification
        ) -> ZMUpdateEvent {
        
        let message = ZMGenericMessage.message(text: text, nonce: UUID.create().transportString())
        return self.decryptedUpdateEventFromOtherClient(message: message, conversation: conversation, source: source)
    }
    
    /// Creates an update event with encrypted message from the other client, decrypts it and returns it
    func decryptedUpdateEventFromOtherClient(message: ZMGenericMessage,
                                             conversation: ZMConversation? = nil,
                                             source: ZMUpdateEventSource = .pushNotification
        ) -> ZMUpdateEvent {
        let cyphertext = self.encryptedMessageToSelf(message: message, from: self.otherClient)
        let innerPayload = ["recipient": self.selfClient.remoteIdentifier!,
                            "sender": self.otherClient.remoteIdentifier!,
                            "text": cyphertext.base64String()
        ]
        let payload = [
            "type": "conversation.otr-message-add",
            "from": self.otherUser.remoteIdentifier!.transportString(),
            "data": innerPayload,
            "conversation": (conversation ?? self.groupConversation).remoteIdentifier!.transportString(),
            "time": Date().transportString()
            ] as [String: Any]
        let wrapper = [
            "id": UUID.create().transportString(),
            "payload": [payload]
            ] as [String: Any]
        
        let event = ZMUpdateEvent.eventsArray(from: wrapper as NSDictionary, source: source)!.first!
        
        var decryptedEvent: ZMUpdateEvent?
        self.selfClient.keysStore.encryptionContext.perform { session in
            decryptedEvent = session.decryptAndAddClient(event, in: self.syncMOC)
        }
        return decryptedEvent!
    }
    
    /// Extract the outgoing message wrapper (non-encrypted) protobuf
    func outgoingMessageWrapper(from request: ZMTransportRequest,
                                file: StaticString = #file,
                                line: UInt = #line) -> ZMNewOtrMessage? {
        guard let protobuf = ZMNewOtrMessage.parse(from: request.binaryData) else {
            XCTFail("No binary data", file: file, line: line)
            return nil
        }
        return protobuf
    }
    
    /// Extract encrypted payload from a request
    func outgoingEncryptedMessage(from request: ZMTransportRequest,
                                  for client: UserClient,
                                  line: UInt = #line,
                                  file: StaticString = #file
        ) -> ZMGenericMessage? {
        
        guard let protobuf = ZMNewOtrMessage.parse(from: request.binaryData) else {
            XCTFail("No binary data", file: file, line: line)
            return nil
        }
        // find user
        let userEntries = protobuf.recipients.flatMap({ $0 })
        guard let userEntry = userEntries.first(where: { $0.user == client.user!.userId() }) else {
            XCTFail("User not found", file: file, line: line)
            return nil
        }
        // find client
        guard let clientEntry = userEntry.clients.first(where: { $0.client == client.clientId }) else {
            XCTFail("Client not found", file: file, line: line)
            return nil
        }
        
        // text content
        guard let cyphertext = clientEntry.text else {
            XCTFail("No text", file: file, line: line)
            return nil
        }
        guard let plaintext = self.decryptMessageFromSelf(cypherText: cyphertext, to: self.otherClient) else {
            XCTFail("failed to decrypt", file: file, line: line)
            return nil
        }
        guard let receivedMessage = ZMGenericMessage.parse(from: plaintext) else {
            XCTFail("Invalid message")
            return nil
        }
        return receivedMessage
    }
}

// MARK: - Internal data provisioning
extension MessagingTestBase {
    
    fileprivate func setupOneToOneConversation(with user: ZMUser) -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
        conversation.conversationType = .oneOnOne
        conversation.remoteIdentifier = UUID.create()
        conversation.connection = ZMConnection.insertNewObject(in: self.syncMOC)
        conversation.connection!.to = user
        conversation.mutableOtherActiveParticipants.add(user)
        return conversation
    }
    
    /// Creates a user and a client
    func createUser(alsoCreateClient: Bool = false) -> ZMUser {
        let user = ZMUser.insertNewObject(in: self.syncMOC)
        user.remoteIdentifier = UUID.create()
        if alsoCreateClient {
            _ = self.createClient(user: user)
        }
        return user
    }
    
    /// Creates a new client for a user
    func createClient(user: ZMUser) -> UserClient {
        let client = UserClient.insertNewObject(in: self.syncMOC)
        client.remoteIdentifier = NSString.createAlphanumerical() as String
        client.user = self.otherUser
        self.syncMOC.saveOrRollback()
        return client
    }
    
    /// Creates a group conversation with a user
    func createGroupConversation(with user: ZMUser) -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
        conversation.conversationType = .group
        conversation.remoteIdentifier = UUID.create()
        conversation.mutableOtherActiveParticipants.add(user)
        return conversation
    }
    
    /// Creates an encryption context in a temp folder and creates keys
    fileprivate func setupUsersAndClients() {
        
        self.otherUser = self.createUser(alsoCreateClient: true)
        self.otherClient = self.otherUser.clients.first!
        self.selfClient = self.createSelfClient()
        
        self.syncMOC.saveOrRollback()
        
        self.establishSessionFromSelf(to: self.otherClient)
    }
    
    /// Creates self client and user
    fileprivate func createSelfClient() -> UserClient {
        let user = ZMUser.selfUser(in: self.syncMOC)
        user.remoteIdentifier = UUID.create()
        
        let selfClient = UserClient.insertNewObject(in: self.syncMOC)
        selfClient.remoteIdentifier = "baddeed"
        selfClient.user = user
        
        self.syncMOC.setPersistentStoreMetadata(selfClient.remoteIdentifier!, key: "PersistedClientId")
        selfClient.type = "permanent"
        self.syncMOC.saveOrRollback()
        return selfClient
    }
}

// MARK: - Internal helpers
extension MessagingTestBase {
    
    func stopEphemeralMessageTimers() {
        self.syncMOC.performGroupedBlockAndWait {
            self.syncMOC.zm_teardownMessageObfuscationTimer()
        }
        _ = self.waitForAllGroupsToBeEmpty(withTimeout: 0.5)
        
        self.uiMOC.performGroupedBlockAndWait {
            self.uiMOC.zm_teardownMessageDeletionTimer()
        }
        _ = self.waitForAllGroupsToBeEmpty(withTimeout: 0.5)
    }
}

// MARK: - Contexts
extension MessagingTestBase {
    
    fileprivate func setupManagedObjectContexes() {
        
        let storeURL = PersistentStoreRelocator.storeURL(in: .cachesDirectory)!
        NSManagedObjectContext.setUseInMemoryStore(true)
        self.uiMOC = NSManagedObjectContext.createUserInterfaceContextWithStore(at: storeURL)
        let imageAssetCache = ImageAssetCache(MBLimit: 100)
        let fileAssetCache = FileAssetCache(location: nil)
        
        self.uiMOC.add(self.dispatchGroup)
        self.uiMOC.userInfo["TestName"] = self.name
        
        self.syncMOC = NSManagedObjectContext.createSyncContextWithStore(at: storeURL, keyStore: storeURL.deletingLastPathComponent())
        self.syncMOC.performGroupedBlockAndWait {
            self.syncMOC.userInfo["TestName"] = self.name
            self.syncMOC.add(self.dispatchGroup)
            self.syncMOC.saveOrRollback()
            
            self.syncMOC.zm_userInterface = self.uiMOC
            self.syncMOC.zm_imageAssetCache = imageAssetCache
            self.syncMOC.zm_fileAssetCache = fileAssetCache
        }
        
        self.uiMOC.zm_sync = self.syncMOC
        self.uiMOC.zm_imageAssetCache = imageAssetCache
        self.uiMOC.zm_fileAssetCache = fileAssetCache
    }
    
    fileprivate func tearDownManagedObjectContexes() {
        self.syncMOC.performGroupedBlockAndWait {
            self.syncMOC.zm_tearDownCryptKeyStore()
            self.syncMOC.userInfo.removeAllObjects()
        }
        self.uiMOC.userInfo.removeAllObjects()
        let refUI = self.uiMOC
        let refSync = self.syncMOC
        
        self.uiMOC = nil
        self.syncMOC = nil
        
        refUI?.performAndWait {
            // wait for any operation to complete
        }
        refSync?.performAndWait {
            // wait for any operation to complete
        }
        refUI?.performAndWait {
            // wait for any operation to complete
        }
        
        NSManagedObjectContext.resetUserInterfaceContext()
        NSManagedObjectContext.resetSharedPersistentStoreCoordinator()
    }
}


// MARK: - Cache cleaning
extension MessagingTestBase {
    
    private var cacheFolder: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    fileprivate func deleteAllFilesInCache() {
        let files = try! FileManager.default.contentsOfDirectory(at: self.cacheFolder, includingPropertiesForKeys: [URLResourceKey.nameKey])
        files.forEach {
            try! FileManager.default.removeItem(at: $0)
        }
    }
}
