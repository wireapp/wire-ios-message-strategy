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


class LinkPreviewUploadRequestStrategyTests: MessagingTest {

    private var sut: LinkPreviewUploadRequestStrategy!
    private var authStatus: MockClientRegistrationStatus!

    override func setUp() {
        super.setUp()
        authStatus = MockClientRegistrationStatus()
        sut = LinkPreviewUploadRequestStrategy(managedObjectContext: syncMOC, clientRegistrationDelegate: authStatus)
        createSelfClient()
    }

    func testThatItDoesNotCreateARequestInState_Done() {
        verifyThatItDoesNotCreateARequest(for: .done)
    }

    func testThatItDoesNotCreateARequestInState_WaitingToBeProcessed() {
        verifyThatItDoesNotCreateARequest(for: .waitingToBeProcessed)
    }

    func testThatItDoesNotCreateARequestInState_Downloaded() {
        verifyThatItDoesNotCreateARequest(for: .downloaded)
    }

    func testThatItDoesNotCreateARequestInState_Processed() {
        verifyThatItDoesNotCreateARequest(for: .processed)
    }

    func testThatItDoesCreateARequestInState_Uploaded() {
        // Given
        let (conversation, message) = insertMessage(with: .uploaded)

        // When
        process(message)

        // Then
        guard let request = sut.nextRequest() else { return XCTFail("No request generated") }
        XCTAssertEqual(request.method, .methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(conversation.remoteIdentifier!.transportString())/otr/messages")
    }

    func testThatItDoesNotCreateARequestAfterGettingsAResponseForIt() {
        // Given
        let (conversation, message) = insertMessage(with: .uploaded)
        process(message)

        // Then
        guard let request = sut.nextRequest() else { return XCTFail("No request generated") }
        XCTAssertEqual(request.method, .methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(conversation.remoteIdentifier!.transportString())/otr/messages")

        // When
        let response = ZMTransportResponse(payload: nil, httpStatus: 200, transportSessionError: nil)
        request.complete(with: response)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // Then
        XCTAssertEqual(message.linkPreviewState.rawValue, ZMLinkPreviewState.done.rawValue)
        XCTAssertNil(sut.nextRequest())
    }

    // MARK: - Helper

    func insertMessage(with state: ZMLinkPreviewState, file: StaticString = #file, line: UInt = #line) -> (ZMConversation, ZMClientMessage) {
        // Given
        let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
        conversation.remoteIdentifier = .create()

        // When
        let message = conversation.appendMessage(withText: "Test message") as! ZMClientMessage
        message.linkPreviewState = state
        XCTAssert(syncMOC.saveOrRollback(), file: file, line: line)

        return (conversation, message)
    }

    func verifyThatItDoesNotCreateARequest(for state: ZMLinkPreviewState, file: StaticString = #file, line: UInt = #line) {
        // Given
        let (_, message) = insertMessage(with: state)

        // When
        process(message)

        // Then
        XCTAssertNil(sut.nextRequest())
    }

    func process(_ message: ZMClientMessage, file: StaticString = #file, line: UInt = #line) {
        sut.contextChangeTrackers.forEach {
            $0.objectsDidChange([message])
        }

        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5), file: file, line: line)
    }
}
