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
@testable import WireMessageStrategy

extension MessagingTest {
    
    @objc public func encrypted(message: ZMGenericMessage, recipient: UserClient) -> Data {
        
        self.establishSession(with: recipient)
        
        var messageData : Data!
        self.syncMOC.zm_cryptKeyStore.encryptionContext .perform { (directory) in
            messageData = try! directory.encrypt(message.data(), recipientIdentifier: recipient.sessionIdentifier!)
        }
        return messageData
    }

    @objc public func establishSession(with client: UserClient) {
    
        let selfUser = ZMUser.selfUser(in: self.syncMOC)
        var lastPrekey : String!
        var hasSession = false
        selfUser.selfClient()!.keysStore.encryptionContext.perform { (directory) in
            if !directory.hasSessionForID(client.sessionIdentifier!) {
                lastPrekey = try! directory.generateLastPrekey()
            } else {
                hasSession = true
            }
        }
        
        if hasSession {
            return
        }
        
        XCTAssertTrue(selfUser.selfClient()!.establishSessionWithClient(client, usingPreKey: lastPrekey))
    }
    
    @objc public func decrypt(updateEvent: ZMUpdateEvent) -> ZMUpdateEvent? {
        var decryptedEvent : ZMUpdateEvent?
        self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { (directory) in
            decryptedEvent = directory.decryptUpdateEventAndAddClient(updateEvent, managedObjectContext: self.syncMOC)
        }
        return decryptedEvent
    }
}
