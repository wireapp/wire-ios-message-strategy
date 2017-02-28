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
import ZMCDataModel
@testable import WireMessageStrategy

class GenericMessageRequestStrategyTests : MessagingTestBase {
    
    let mockClientRegistrationStatus = MockClientRegistrationStatus()
    var sut : GenericMessageRequestStrategy!
    
    override func setUp() {
        super.setUp()
        
        sut = GenericMessageRequestStrategy(context: syncMOC, clientRegistrationDelegate: mockClientRegistrationStatus)
    }
    
    func testThatItCreatesARequestForAGenericMessage() {
        
        // given
        let genericMessage = ZMGenericMessage(editMessage: "foo", newText: "bar", nonce: UUID.create().transportString())
        sut.schedule(message: genericMessage, inConversation: self.groupConversation) { ( _ ) in }
        
        // when
        let request = sut.nextRequest()
        
        // then
        XCTAssertEqual(request!.method, .methodPOST)
        XCTAssertEqual(request!.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
    }
    
    func testThatItForwardsObjectDidChangeToTheSync(){
        // given
        self.selfClient.missesClient(self.otherClient)
        
        let genericMessage = ZMGenericMessage(editMessage: "foo", newText: "bar", nonce: UUID.create().transportString())
        sut.schedule(message: genericMessage, inConversation: self.groupConversation) { ( _ ) in }
        
        // when
        let request1 = sut.nextRequest()
        
        // then
        XCTAssertNil(request1)
        
        // and when
        selfClient.removeMissingClient(self.otherClient)
        sut.objectsDidChange(Set([selfClient]))
        let request2 = sut.nextRequest()

        // then
        XCTAssertEqual(request2!.method, .methodPOST)
        XCTAssertEqual(request2!.path, "/conversations/\(self.groupConversation.remoteIdentifier!.transportString())/otr/messages")
    }
    
}
